module Xjz
  class Tracker
    attr_reader :history

    class << self
      def instance
        @instance ||= new
      end

      def track_req(*args)
        instance.track_req(*args)
      end
    end

    def initialize
      @history = []
    end

    def track_req(*args)
      RequestTracker.new(*args).tap { |rt| @history << rt }
    end
  end

  class RequestTracker
    attr_reader :request, :response, :action_list, :action_hash

    def initialize(request, auto_start: true)
      @request = request
      @response = nil
      @action_list = []
      @action_hash = {}
      start if auto_start
    end

    def start
      track 'start'
    end

    def track(name, &block)
      r = [Time.now]
      if block
        block.call
        r << Time.now
      end
      @action_list << [name, r]
      @action_hash[name] = r
      true
    end

    def finish(response)
      track 'finish'
      @response = response
    end

    def seconds
      return 0 if action_list.length < 2
      action_list[-1][1].last - action_list[0][1].first
    end
  end
end