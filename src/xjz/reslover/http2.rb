module Xjz
  class Reslover::HTTP2
    attr_reader :original_req, :conn

    HTTP2_REQ_DATA = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    def initialize(req)
      @original_req = req
      @user_conn = req.user_socket
      @resolver_server = init_h2_resolver
      @remote_sock = nil
      @remote_h2_conn = nil
      @proxy_client
    end

    def perform
      @resolver_server << HTTP2_REQ_DATA
      RequestHelper.forward_streams(@user_conn => WriterIO.new(@resolver_server))
      @remote_sock.close if @remote_sock
      Logger[:http2_proxy].debug("Finished #{original_req.host}")
      [200, { 'content-length' => 0 }, []]
    end

    def init_h2_resolver
      conn = HTTP2::Server.new
      user_conn = @user_conn
      conn.on(:frame) do |bytes|
        user_conn.write(bytes)
        stream_name = RequestHelper.stream_inspect(user_conn)
        Logger[:http2_proxy].debug "Recv #{bytes.size} bytes from #{stream_name}"
      end

      conn.on(:stream) do |stream|
        header = []
        buffer = []

        stream.on(:headers) { |h| header.push(*h) }
        stream.on(:data) { |d| buffer << d }

        stream.on(:half_close) do
          Logger[:http2_proxy].debug("Request #{header} with data #{buffer.join.size} bytes")
          req = Request.new_for_h2(original_req.env, header, buffer)
          ssl_sock = fetch_remote_socket(req.host, req.port)

          if ssl_sock.alpn_protocol == 'h2'
            proxy_http2_stream(stream, req)
          else
            proxy_http1_stream(stream, req)
          end

          Logger[:http2_proxy].debug "end_stream"
        end
      end
      conn
    end

    def fetch_remote_h2_conn
      @remote_h2_conn = HTTP2::Client.new
    end

    def fetch_remote_socket(host, port)
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
      Logger[:http2_proxy].debug "Connect #{req.host} with http2"
      remote_h2_conn = fetch_remote_h2_conn
      remote_stream = remote_h2_conn.new_stream
      res_header = []
      res_buffer = []

      remote_h2_conn.on(:frame) do |bytes|
        @remote_sock << bytes
      end

      # conn.on(:promise) do |promise|
      #   promise.on(:promise_headers) do |h|
      #     Logger[:http2_proxy].debug "promise request headers: #{h}"
      #   end

      #   promise.on(:headers) do |h|
      #     Logger[:http2_proxy].info "promise headers: #{h}"
      #   end

      #   promise.on(:data) do |d|
      #     Logger[:http2_proxy].info "promise data chunk: <<#{d.size}>>"
      #   end
      # end

      remote_stream.on(:headers) { |h| res_header.push(*h) }
      remote_stream.on(:data) { |d| res_buffer << d }

      remote_stream.on(:close) do
        Logger[:http2_proxy].debug "Response header #{res_header.inspect}"
        res = Response.new(res_header, res_buffer)
        stream.headers(res.h2_headers, end_stream: false)

        Logger[:http2_proxy].debug "Response body #{res.body.bytesize} bytes"
        stream.data(res.body, end_stream: true)
      end

      if req.body.empty?
        remote_stream.headers(req.headers, end_stream: true)
      else
        remote_stream.headers(req.headers, end_stream: false)
        remote_stream.data(req.body, end_stream: true)
      end

      RequestHelper.forward_streams(@remote_sock => WriterIO.new(remote_h2_conn))
    end

    def proxy_http1_stream(stream, req)
      Logger[:http2_proxy].info "Connect #{req.host} with http/1.1"
      res = Reslover::HTTP1.new(req).response

      stream.headers(res.h2_headers, end_stream: false)
      stream.data(res.body, end_stream: true)
    end
  end
end
