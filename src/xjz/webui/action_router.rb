#
# ActionRouter.new do
#   namespace 'proxy' do
#     event 'start' do
#     end
#     event /^proxy.stop$/ do
#     end
#   end
#   event /^xxx.yyy/ do
#   end
# end
#
# Matchers:
# string: start_with?(str + '.') & inner matcher skip the prefix
# regexp: match(regexp) & inner matcher still keep the original string
#
module Xjz
  class WebUI::ActionRouter
    attr_reader :matcher, :events, :current_cls, :classes, :last_runner

    def self.register(name, &block)
      default.register(name, &block)
    end

    def self.default
      @default ||= self.new
    end

    def initialize(matcher = //, cls = nil, &block)
      @regexp = matcher
      @events = {}
      @current_cls = cls
      @classes = {}
      instance_eval(&block) if block
    end

    def register(name, &block)
      @current_cls = Class.new(WebUI::ActionRunner)
      classes[name.to_s] = @current_cls
      instance_eval(&block)
      @current_cls = nil
    end

    # Params:
    #   msg: method `type` and `data` is required
    # Returns:
    #   true: processed
    #   false: not found performer
    def call(msg, _sub_str = nil)
      _sub_str ||= msg.type
      events.each do |matcher, performer|
        if String === matcher && _sub_str.start_with?(matcher)
          r = run_performer(performer, msg, _sub_str[(matcher.length)..-1])
          return r if r
        elsif Regexp === matcher && m = matcher.match(_sub_str)
          r = run_performer(performer, msg, nil, m)
          return r if r
        end
      end
      false
    end

    # namespace 'prefix' => match /^prefix\./
    def namespace(matcher, &block)
      raise "action block cannot be nil" if block.nil?
      matcher += '.' if String === matcher
      (events[matcher] ||= self.class.new(matcher, current_cls)).tap do |obj|
        obj.instance_eval(&block)
      end
    end

    def event(matcher, &block)
      raise "action block cannot be nil" if block.nil?
      events[matcher] = [block, current_cls]
    end

    def helpers(&block)
      current_cls.class_eval(&block)
    end

    private

    def run_performer(performer, msg, sub_str = nil, match_data = nil)
      block, runner_cls = performer
      if self.class === block
        block.call(msg, sub_str)
      else
        runner = runner_cls.new(msg, match_data)
        runner.instance_eval(&block)
        runner_cls.last_runner = runner
        true
      end
    end
  end
end
