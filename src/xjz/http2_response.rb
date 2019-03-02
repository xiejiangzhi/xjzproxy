module Xjz
  class HTTP2Response
    attr_reader :env, :conn

    HTTP2_REQ_DATA = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    class HTTP2Stream
      def initialize(connection)
        @conn = connection
      end

      def write(data)
        @conn.receive(data)
      end

      def close_write; end
      def flush; end

      def remote_address
        nil
      end
    end

    def initialize(env)
      @env = env
      @user_conn = env['puma.socket']
      @resolver_server = init_h2_resolver
      @remote_sock = nil
      @remote_h2_conn = nil
      @proxy_client
    end

    def to_response
      @resolver_server << HTTP2_REQ_DATA
      RequestHelper.forward_streams(@user_conn => HTTP2Stream.new(@resolver_server))
      @remote_sock.close if @remote_sock
      Logger[:http2_proxy].debug("Finished #{env['HTTP_HOST']}")
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
          RequestHelper.import_h2_header_to_env(env, header)
          Logger[:http2_proxy].debug("Request #{header} with data #{buffer.join.size} bytes")
          host, port = env['HTTP_HOST'].split(':')
          port ||= env['SERVER_PORT']
          scheme_port = (env['H2_SCHEME'] == 'https') ? '443' : '80'
          url_port = (port == scheme_port) ? '' : ":#{port}"
          env['xjz.url'] = "https://#{host}#{url_port}#{env['REQUEST_PATH']}"

          ssl_sock = fetch_remote_socket(host, port)

          if ssl_sock.alpn_protocol == 'h2'
            proxy_http2_stream(stream, header, buffer)
          else
            proxy_http1_stream(stream, buffer)
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

    def proxy_http2_stream(stream, req_header, req_buffer)
      Logger[:http2_proxy].debug "Connect #{env['HTTP_HOST']} with http2"
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
        body = res_buffer.join
        Logger[:http2_proxy].debug "Response header #{res_header.inspect}"
        stream.headers(res_header, end_stream: false)

        Logger[:http2_proxy].debug "Response body #{body.size} bytes"
        stream.data(body, end_stream: true)
      end

      if req_buffer.empty?
        remote_stream.headers(req_header, end_stream: true)
      else
        remote_stream.headers(req_header, end_stream: false)
        remote_stream.data(req_buffer.join, end_stream: true)
      end

      RequestHelper.forward_streams(@remote_sock => HTTP2Stream.new(remote_h2_conn))
    end

    def proxy_http1_stream(stream, req_buffer)
      Logger[:http2_proxy].info "Connect #{env['HTTP_HOST']} with http/1.1"
      req_method = env['REQUEST_METHOD'].downcase
      header, body = RequestHelper.generate_h2_response(HTTP1Response.new(req_method, env).to_response)

      stream.headers(header, end_stream: false)
      stream.data(body, end_stream: true)
    end
  end
end
