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
      @mutex = Mutex.new
    end

    def clean_all
      @history.clear
    end

    def track_req(*args)
      RequestTracker.new(*args).tap do |rt|
        @mutex.synchronize { @history << rt }
        $config.shared_data.app.webui.emit_message('tracker.new_request', rt: rt)
      end
    end


  end

  class RequestTracker
    attr_reader :request, :response, :action_list, :action_hash, :error_msg, :api_project, :api
    attr_accessor :rt_diff

    def initialize(request, auto_start: true, api_project: nil, api: nil)
      @request = request
      @api_project = api_project
      @api = api
      @response = nil
      @action_list = []
      @action_hash = {}
      @rt_diff = {}
      request.api_project = api_project if api_project
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
      @diff = nil
      response.api_project = api_project if api_project
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
          res_desc = api_project.find_api(req.http_method, req.path)
          res_desc ? [:http, res_desc] : []
        end
      end
    end

    def diff
      return unless api_project && api_desc.present?

      @diff ||= begin
        _, ad = api_desc
        req = request
        pairs = [
          [:query, ad['query'], req.query_hash],
          [:req_body, ad['body'], req.body_hash],
        ]
        pairs << [:params, ad['params'], req.params] if ad['params']
        pairs << [:req_headers, ad['headers'], Hash[req.proxy_headers], allow_extend: true]

        res = response
        if response && ad && succ_desc = ad.dig('response', 'success')
          pairs += [
            [:code, succ_desc['http_code'] || 200, res.code],
            [:res_headers, succ_desc['headers'], Hash[res.h2_headers], allow_extend: true],
          ]

          if res.body_hash.blank? && res.body.to_s.strip !~ /\A[\[\{]/
            pairs << [:res_body, succ_desc['data'], res.body]
          else
            pairs << [:res_body, succ_desc['data'], res.body_hash]
          end
        end

        pairs.each_with_object({}) do |data, r|
          code, expected, actual, opts = data
          expected ||= {}
          actual ||= {}
          diff = Xjz::ParamsDiff.new(opts || {}).diff(expected, actual, 'Data')
          next if diff.blank?
          r[code] = diff
        end
      end
    end

    def memsize
      Helper::Memsize.count(self) +
        Helper::Memsize.count(request) * 1.2 +
        Helper::Memsize.count(response) * 1.1
    end
  end
end
