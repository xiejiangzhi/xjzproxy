module Support
  module DataHelper
    def new_http1_req_headers
      [
        ["host", "xjz.pw"],
        ["user_agent", "curl/7.54.0"],
        ["accept", "*/*"],
        ["connection", "Keep-Alive"],
      ]
    end

    def new_http2_req_headers
      [
        [":method", "GET"],
        [":path", "/?a=123"],
        [":scheme", "https"],
        [":authority", "xjz.pw"],
        ["user_agent", "curl/7.54.0"],
        ["accept", "*/*"],
        ["proxy_connection", "Keep-Alive"],
      ]
    end

    def new_http1_res_headers(keep_alive: false)
      [
        ["content-type", "text/plain"],
        ["content-length", "12"],
        ["connection", keep_alive ? 'keep-alive' : "close"]
      ]
    end

    def new_http2_res_headers
      [
        [":status", "200"],
        ["content-type", "text/plain"],
        ["content-length", "12"],
      ]
    end

    def new_req_env
      {
        "rack.errors" => 'error.io',
        "rack.multithread" => true,
        "rack.multiprocess" => false,
        "rack.run_once" => false,
        "SCRIPT_NAME" => "",
        "QUERY_STRING" => "a=123",
        "SERVER_PROTOCOL" => "HTTP/1.1",
        "GATEWAY_INTERFACE" => "CGI/1.2",
        "REQUEST_METHOD" => "GET",
        "REQUEST_URI" => "http://xjz.pw/",
        "HTTP_HOST" => "xjz.pw",
        "HTTP_USER_AGENT" => "curl/7.54.0",
        "HTTP_ACCEPT" => "*/*",
        "HTTP_PROXY_CONNECTION" => "Keep-Alive",
        "HTTP_CONTENT_TYPE" => "text/plain; charset=utf-8",
        "HTTP_CONNECTION" => "keep-alive",
        "SERVER_NAME" => "baidu.com",
        "SERVER_PORT" => "80",
        "REQUEST_PATH" => "/asdf",
        "PATH_INFO" => "/asdf",
        "REMOTE_ADDR" => "127.0.0.1",
        "rack.hijack?" => true,
        "rack.hijack" => proc { 'user_socket' },
        "rack.hijack_io" => 'user_socket',
        "rack.input" => StringIO.new('hello'),
        "rack.url_scheme" => "http",
      }
    end

    def new_webmsg(type, data = {})
      Xjz::WebUI::PageManager::Message.new(
        type, data, $config.shared_data.app.webui.page_manager
      )
    end

    def web_router
      Xjz::WebUI::ActionRouter.default
    end
  end
end
