module Xjz
  class Reslover::HTTP2
    attr_reader :original_req, :conn, :host, :port

    HTTP2_REQ_DATA = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
    UPGRADE_RES = [
      'HTTP/1.1 101 Switching Protocols',
      'Connection: Upgrade',
      'Upgrade: h2c'
    ].join("\r\n") + "\r\n\r\n"

    def initialize(req)
      @original_req = req
      @user_conn = req.user_socket
      @resolver_server = init_h2_resolver
      @remote_sock = nil
      @host, @port = nil
      @req_scheme = req.scheme
    end

    def perform
      upgrade_to_http2 if original_req.upgrade_flag
      resolver_server << HTTP2_REQ_DATA
      IOHelper.forward_streams(@user_conn => WriterIO.new(resolver_server))
      Logger[:auto].debug { "Finished #{original_req.host}" }
      [0, {}, []]
    ensure
      @remote_sock.close if @remote_sock
    end

    private

    attr_reader :user_conn, :resolver_server, :req_scheme

    def init_h2_resolver
      conn = HTTP2::Server.new
      conn.on(:frame) do |bytes|
        stream_name = IOHelper.stream_inspect(user_conn)
        Logger[:auto].debug { "Send #{bytes.size} bytes to #{stream_name}" }
        user_conn.write(bytes)
      end

      conn.on(:stream) do |stream|
        header = []
        buffer = []

        stream.on(:headers) { |h| header.push(*h) }
        stream.on(:data) { |d| buffer << d }

        stream.on(:half_close) do
          # Logger[:http2_proxy].debug { "Request #{header} with data #{buffer.join.size} bytes" }
          req = Request.new_for_h2(original_req.env, header, buffer)
          @host ||= req.host
          @port ||= req.port
          Logger[:auto].info { "#{req.http_method} #{req.host}:#{req.port}" }

          if remote_support_h2?
            proxy_http2_stream(stream, req)
          else
            proxy_http1_stream(stream, req)
          end

          Logger[:auto].debug { "end_stream" }
        end
      end
      conn
    end

    def remote_sock
      return unless host && port
      @remote_sock ||= begin
        sock = TCPSocket.new(host, port)
        if req_scheme == 'https'
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.alpn_protocols = %w{h2 http/1.1}
          ssl_sock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
          ssl_sock.hostname = host
          ssl_sock.connect
          ssl_sock
        else
          sock
        end
      end
    end

    def remote_support_h2?
      @remote_support_h2 = if req_scheme == 'https'
        if remote_sock.alpn_protocol == 'h2'
          true
        else
          false
        end
      else
        ProxyClient.h2_test(original_req)
      end
    end

    def upgrade_to_http2
      req = original_req
      user_conn.write(UPGRADE_RES)
      settings = req.get_header('http2-settings')
      req_headers = [
        [':scheme', 'http'],
        [':method', req.http_method],
        [':authority', req.get_header('host')],
        [':path', req.rack_req.fullpath],
        *req.proxy_headers
      ]
      resolver_server.upgrade(settings, req_headers, req.body)
    end

    def proxy_http2_stream(stream, req)
      res = proxy_client.send_req(req)
      stream.headers(res.h2_headers, end_stream: false)
      stream.data(res.body)
    end

    def proxy_http1_stream(stream, req)
      Logger[:auto].info { "Connect #{req.host} with http/1.1" }
      res = proxy_client.send_req(req)

      stream.headers(res.h2_headers, end_stream: false)
      stream.data(res.body, end_stream: true)
    end

    def proxy_client
      @proxy_client ||= ProxyClient.new(
        protocol: remote_support_h2? ? 'http2' : 'http1'
      )
    end
  end
end