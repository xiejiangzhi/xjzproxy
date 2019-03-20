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
  end
end
