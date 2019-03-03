module Xjz
  class Reslover::HTTP2
    attr_reader :original_req, :conn, :host, :port

    HTTP2_REQ_DATA = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    def initialize(req)
      @original_req = req
      @user_conn = req.user_socket
      @resolver_server = init_h2_resolver
      @remote_sock = nil
      @host, @port = nil
    end

    def perform
      @resolver_server << HTTP2_REQ_DATA
      IOHelper.forward_streams(@user_conn => WriterIO.new(@resolver_server))
      Logger[:http2_proxy].debug { "Finished #{original_req.host}" }
      [200, { 'content-length' => 0 }, []]
    ensure
      @remote_sock.close if @remote_sock
    end

    def init_h2_resolver
      conn = HTTP2::Server.new
      user_conn = @user_conn
      conn.on(:frame) do |bytes|
        user_conn.write(bytes)
        stream_name = IOHelper.stream_inspect(user_conn)
        Logger[:http2_proxy].debug { "Recv #{bytes.size} bytes from #{stream_name}" }
      end

      conn.on(:stream) do |stream|
        header = []
        buffer = []

        stream.on(:headers) { |h| header.push(*h) }
        stream.on(:data) { |d| buffer << d }

        stream.on(:half_close) do
          Logger[:http2_proxy].debug { "Request #{header} with data #{buffer.join.size} bytes" }
          req = Request.new_for_h2(original_req.env, header, buffer)
          @host ||= req.host
          @port ||= req.port
          Logger[:server].info { "#{req.http_method} #{req.host}:#{req.port}" }

          if remote_sock.alpn_protocol == 'h2'
            proxy_http2_stream(stream, req)
          else
            proxy_http1_stream(stream, req)
          end

          Logger[:http2_proxy].debug { "end_stream" }
        end
      end
      conn
    end

    def remote_sock
      return unless host && port
      @remote_sock ||= begin
        sock = TCPSocket.new(host, port)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.alpn_protocols = %w{h2 http/1.1}
        ssl_sock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
        ssl_sock.hostname = host
        ssl_sock.connect
        ssl_sock
      end
    end

    def proxy_http2_stream(stream, req)
      res = proxy_client.send_req(req)
      stream.headers(res.h2_headers, end_stream: false)
      stream.data(res.body)
    end

    def proxy_http1_stream(stream, req)
      Logger[:http2_proxy].info { "Connect #{req.host} with http/1.1" }
      res = proxy_client.send_req(req)

      stream.headers(res.h2_headers, end_stream: false)
      stream.data(res.body, end_stream: true)
    end

    def proxy_client
      @proxy_client ||= ProxyClient.new(
        protocol: remote_sock.alpn_protocol == 'h2' ? 'http2' : 'http1'
      )
    end
  end
end
