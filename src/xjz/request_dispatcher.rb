module Xjz
  class RequestDispatcher
    VALID_REQUEST_METHODS = %w{get head options trace post put patch delete}

    def call(env)
      req = Request.new(env)

      Logger[:auto].debug do
        headers = req.headers.map { |kv| kv.join(': ') }.join(', ')
        "#{req.http_method} #{req.host}:#{req.port} - #{headers}"
      end

      ap = find_api_project(req)
      if local_request?(req)
        Resolver::WebUI.new(req, ap).perform
      elsif process_conn?(ap, req)
        dispatch_request(ap, req)
      else
        Resolver::Forward.new(req, ap).perform
      end
    end

    private

    def find_api_project(req)
      aps = $config['.api_projects']
      (Xjz.LICENSE_CHECK() ? aps : [aps[0]]).find { |ap| ap.match_host?(req.host) }.tap do |r|
        Logger[:auto].debug { "Find api project by #{req.host}: #{r&.repo_path.inspect}" }
      end
    end

    def process_conn?(ap, req)
      case $config['proxy_mode']
      when 'all'
        true # will process all
      when 'whitelist'
        (ap || $config['host_whitelist'].include?(req.host)) ? true : false
      when
        Logger[:auto].error { "Invalid proxy mode #{$config['proxy_mode']}, use whitelist" }
        (ap || $config['host_whitelist'].include?(req.host)) ? true : false
      end
    end

    def dispatch_request(ap, req)
      req_method = req.http_method
      IOHelper.set_proxy_host_port(req.user_socket, req.host, req.port)

      if req_method == 'connect'
        if ap&.grpc
          Resolver::GRPC.new(req, ap).perform
        else
          Resolver::SSL.new(req, ap).perform
        end
      elsif flag = req.upgrade_flag
        case flag
        when 'h2c'
          Resolver::HTTP2.new(req, ap).perform
        when 'websocket'
          Resolver::Forward.new(req, ap).perform
        else
          Logger[:auto].error { "Cannot handle request upgrade #{flag}" }
        end
      elsif req_method == 'pri'
        Resolver::HTTP2.new(req, ap).perform
      elsif VALID_REQUEST_METHODS.include?(req_method)
        Resolver::HTTP1.new(req, ap).perform
      else
        Logger[:auto].error { "Cannot handle request #{req.inspect}" }
      end
    end

    def local_request?(req)
      req.user_socket.is_a?(TCPSocket) && req.env['REQUEST_URI'] =~ %r{^/}
    end
  end
end
