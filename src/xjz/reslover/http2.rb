module Xjz
  class Reslover::HTTP2
    attr_reader :original_req, :conn, :host, :port, :proxy_client

    UPGRADE_RES = [
      'HTTP/1.1 101 Switching Protocols',
      'Connection: Upgrade',
      'Upgrade: h2c'
    ].join("\r\n") + "\r\n\r\n"

    def initialize(req)
      @original_req = req
      @user_conn = req.user_socket
      @resolver_server = init_h2_resolver
      @host, @port = req.host, req.port
      @req_scheme = req.scheme
      @remote_support_h2 = nil
    end

    def perform
      Logger[:auto].info { "Perform by HTTP2" }
      check_remote_server
      upgrade_to_http2 if original_req.upgrade_flag
      resolver_server << HTTP2_REQ_HEADER
      IOHelper.forward_streams(@user_conn => WriterIO.new(resolver_server))
    ensure
      @proxy_client.close if @proxy_client
    end

    private

    attr_reader :user_conn, :resolver_server, :req_scheme

    def init_h2_resolver
      conn = HTTP2::Server.new
      conn.on(:frame) do |bytes|
        begin
          user_conn << bytes unless user_conn.closed?
        rescue Errno::EPIPE => e
          Logger[:auto].error { e.log_inspect }
        end
      end

      # conn.on(:frame_received) do |frame|
      #   Logger[:auto].debug { "Recv #{frame.inspect}" }
      # end

      # conn.on(:frame_sent) do |frame|
      #   Logger[:auto].debug { "Sent #{frame.inspect}" }
      # end

      conn.on(:stream) do |stream|
        header = []
        buffer = []

        stream.on(:headers) { |h| header.push(*h) }
        stream.on(:data) { |d| buffer << d }

        stream.on(:half_close) do
          Logger[:auto].debug { "Recv HTTP2 Request" }
          req = Request.new_for_h2(original_req.env, header, buffer)

          if remote_support_h2?
            proxy_http2_stream(stream, req)
          else
            proxy_http1_stream(stream, req)
          end
          Logger[:auto].debug { "Finished HTTP2 Request" }
        end
      end
      conn
    end

    def remote_support_h2?
      @remote_support_h2
    end

    def upgrade_to_http2
      Logger[:auto].debug { "Send upgrade request" }
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
      _res = proxy_client.send_req(req) do |event, data, flags|
        case event
        when :headers
          stream.headers(
            data,
            end_stream: flags.include?(:end_stream),
            end_headers: flags.include?(:end_headers)
          )
        when :data
          stream.data(data, end_stream: flags.include?(:end_stream))
        end
      end
    end

    def proxy_http1_stream(stream, req)
      res = proxy_client.send_req(req)
      stream.headers(res.h2_headers, end_stream: false)
      stream.data(res.body, end_stream: true)
    end

    def check_remote_server
      protocol, @proxy_client = ProxyClient.auto_new_client(original_req)
      @remote_support_h2 = (protocol == :h2 || protocol == :h2c)
    end
  end
end
