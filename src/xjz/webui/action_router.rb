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
    attr_reader :env_obj, :matcher, :events

    def self.register(&block)
      default.instance_eval(&block)
    end

    def self.default
      @default ||= self.new
    end

    def initialize(matcher = //, &block)
      @regexp = matcher
      @events = {}
      instance_eval(&block) if block
    end

    # Params:
    #   env_obj: method `type` and `data` is required
    # Returns:
    #   true: processed
    #   false: not found performer
    def call(env_obj, _sub_str = nil)
      _sub_str ||= env_obj.type
      events.each do |matcher, performer|
        # binding.pry if $a == 1
        if String === matcher && _sub_str.start_with?(matcher)
          r = run_performer(performer, env_obj, _sub_str[(matcher.length)..-1])
          return r if r
        elsif Regexp === matcher && matcher.match?(_sub_str)
          r = run_performer(performer, env_obj)
          return r if r
        end
      end
      false
    end

    # namespace 'prefix' => match /^prefix\./
    def namespace(matcher, &block)
      raise "action block cannot be nil" if block.nil?
      matcher += '.' if String === matcher
      events[matcher] = self.class.new(matcher, &block)
    end

    def event(matcher, &block)
      raise "action block cannot be nil" if block.nil?
      events[matcher] = block
    end

    private

    def run_performer(performer, env_obj, sub_str = nil)
      if self.class === performer
        performer.call(env_obj, sub_str)
      else
        env_obj.instance_eval(&performer)
        true
      end
    end
  end
end
