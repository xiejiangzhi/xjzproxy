module Xjz
  class RequestDispatcher
    VALID_REQUEST_METHODS = %w{get head options trace post put patch delete}

    def call(env)
      req = Request.new(env)
      req_method = req.http_method

      if req_method == 'connect'
        SSLReslover.new(req).perform
      elsif web_ui_request?(req)
        WebUIReslover.new(req).perform
      elsif req_method == 'pri'
        HTTP2Reslover.new(req).perform
      elsif VALID_REQUEST_METHODS.include?(req_method)
        HTTP1Reslover.new(req).perform
      else
        raise "Cannot handle request #{req.inspect}"
      end
    end

    def web_ui_request?(req)
      req.user_socket.is_a?(TCPSocket) && req.env['REQUEST_URI'] =~ %r{^/}
    end
  end
end
