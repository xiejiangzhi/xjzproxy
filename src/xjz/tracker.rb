module Xjz
  class Tracker
    attr_reader :history

    class << self
      def instance
        @instance ||= new
      end

      # track_req(request, auto_start: true, api_project: nil, api: nil)
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
        $config.shared_data.app.webui.emit_message('tracker.new_request', rt: rt)
      end
    end
  end

  class RequestTracker
    attr_reader :request, :response, :action_list, :action_hash, :error_msg, :api_project, :api

    def initialize(request, auto_start: true, api_project: nil, api: nil)
      @request = request
      @api_project = api_project
      @api = api
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
      $config.shared_data.app.webui.emit_message('tracker.update_request', rt: self)
      true
    end

    def finish(response)
      @response = response
      track 'finish'
    end

    def error(msg)
      @error_msg = msg
      track 'error'
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

    def api_desc
      return unless api_project
      @definition ||= begin
        req = request
        if grpc = api_project.grpc
          res_desc = grpc.res_desc(req.path)
          res_desc ? [:grpc, res_desc] : []
        else
          res_desc = api_project.find_api(req.http_method, req.scheme, req.host, req.path)
          res_desc ? [:http, res_desc] : []
        end
      end
    end
  end
end
