module Xjz
  class RequestDispatcher
    VALID_REQUEST_METHODS = %w{get head options trace post put patch delete}

    def call(env)
      req = Request.new(env)

      Logger[:auto].debug do
        headers = req.headers.map { |kv| kv.join(': ') }.join(', ')
        "#{req.http_method} #{req.host}:#{req.port} - #{headers}"
      end

      if process_conn?(req)
        dispatch_request(req)
      else
        Reslover::Forward.new(req).perform
      end
    end

    private

    def process_conn?(req)
      case $config['proxy_mode']
      when 'projects'
        $config['.api_projects'].any? { |ap| ap.match_host?(req.host) }
      when 'whitelist'
        $config['.api_projects'].any? { |ap| ap.match_host?(req.host) } ||
          $config['host_whitelist'].include?(req.host)
      when 'blacklist'
        !$config['host_blacklist'].include?(req.host)
      when 'all'
        true
        # will process all
      else
        Logger[:auto].error { "Invalid proxy mode #{$config['proxy_mode']}" }
        false
      end
    end

    def grpc_tunnel?(req)
      $config['.api_projects'].any? do |ap|
        ap.match_host?(req.host) && ap.data['project']['grpc']
      end
    end

    def dispatch_request(req)
      req_method = req.http_method
      IOHelper.set_proxy_host_port(req.user_socket, req.host, req.port)

      if req_method == 'connect'
        if grpc_tunnel?(req)
          Reslover::GRPC.new(req).perform
        else
          Reslover::SSL.new(req).perform
        end
      elsif flag = req.upgrade_flag
        case flag
        when 'h2c'
          Reslover::HTTP2.new(req).perform
        when 'websocket'
          Reslover::Forward.new(req).perform
        else
          Logger[:auto].error { "Cannot handle request upgrade #{flag}" }
        end
      elsif web_ui_request?(req)
        Reslover::WebUI.new(req).perform
      elsif req_method == 'pri'
        Reslover::HTTP2.new(req).perform
      elsif VALID_REQUEST_METHODS.include?(req_method)
        Reslover::HTTP1.new(req).perform
      else
        Logger[:auto].error { "Cannot handle request #{req.inspect}" }
      end
    end

    def web_ui_request?(req)
      req.user_socket.is_a?(TCPSocket) && req.env['REQUEST_URI'] =~ %r{^/}
    end
  end
end
