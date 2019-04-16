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

    def clean_all
      @history = []
    end

    def track_req(*args)
      RequestTracker.new(*args).tap do |rt|
        @history << rt
        $config.shared_data.app.webui.emit_message('new_request', rt)
      end
    end
  end

  class RequestTracker
    attr_reader :request, :response, :action_list, :action_hash, :error_msg

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

    def error(msg)
      track 'error'
      @error_msg = msg
    end

    def start_at
      action_list[0][1].first
    end

    def end_at
      action_list[-1][1].last
    end

    def cost
      return 0 if action_list.length < 2
      end_at - start_at
    end
  end
end
