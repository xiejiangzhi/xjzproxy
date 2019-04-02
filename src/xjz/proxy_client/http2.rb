module Xjz
  class ProxyClient::HTTP2
    attr_reader :client, :host, :port, :use_ssl, :upgrade

    UPGRADE_DATA = <<~REQ
      GET / HTTP/1.1\r
      Connection: Upgrade, HTTP2-Settings\r
      HTTP2-Settings: %{settings}\r
      Upgrade: h2c\r
      Host: %{host}\r
      User-Agent: http-2 upgrade\r
      Accept: */*\r
      \r
    REQ

    def initialize(host, port, ssl: false, upgrade: false)
      @host, @port = host, port
      @use_ssl = ssl
      @upgrade = upgrade
      @client = HTTP2::Client.new
      init_client(@client)
    end

    def ping
      v = []
      client.ping('a' * 8) { v << 1 }
      IOHelper.forward_streams(
        { remote_sock => WriterIO.new(client) },
        stop_wait_cb: proc { v.present? }
      )
      v.present?
    end

    def send_req(req, &cb_stream)
      stream = client.new_stream
      res_header = []
      res_buffer = []
      res = nil
      stop_wait = false

      stream.on(:headers) do |h, f|
        res_header.push(*h)
        cb_stream.call(:headers, h, f) if cb_stream
      end
      stream.on(:data) do |d, f|
        res_buffer << d
        cb_stream.call(:data, d, f) if cb_stream
      end
      stream.on(:close) do
        stop_wait = true
        res = Response.new(res_header, res_buffer)
        cb_stream.call(:close) if cb_stream
      end

      Logger[:auto].debug { "Send request stream #{req.headers.inspect} #{req.body.inspect}" }
      if req.body.empty?
        stream.headers(req.headers)
      else
        stream.headers(req.headers, end_stream: false)
        stream.data(req.body)
      end

      IOHelper.forward_streams(
        { remote_sock => WriterIO.new(client) },
        stop_wait_cb: proc { stop_wait }
      )
      res
    end

    def close
      remote_sock.close
    end

    def remote_sock
      @remote_sock ||= begin
        sock = Socket.tcp(host, port, connect_timeout: $config['proxy_timeout'])
        if use_ssl
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.alpn_protocols = %w{h2}
          ssl_sock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
          ssl_sock.sync_close = true
          ssl_sock.hostname = host
          IOHelper.ssl_connect(ssl_sock)
          ssl_sock
        else
          sock
        end
      end
    end

    private

    def init_client(client)
      if @upgrade
        upgrade_req = (UPGRADE_DATA % {
          host: host,
          settings: HTTP2::Client.settings_header(client.local_settings)
        })
        Logger[:auto].debug { upgrade_req.inspect }
        remote_sock << upgrade_req
        result = []
        HTTPParser.parse_response(remote_sock) { |*r| result.concat(r) }
        code, headers, body = result
        Logger[:auto].debug { "#{code} #{headers.inspect} #{body.inspect}" }
        Logger[:auto].error { "Could not upgrade h2c, code: #{code}" } unless code == 101
      end

      client.on(:frame) do |bytes|
        begin
          remote_sock << bytes
        rescue Errno::EPIPE => e
          Logger[:auto].debug { e.log_inspect }
        end
      end
      # client.on(:frame_sent) do |frame|
      #   Logger[:auto].debug { "-> #{frame.inspect}" }
      # end
      # client.on(:frame_received) do |frame|
      #   Logger[:auto].debug { "<- #{frame.inspect}" }
      # end

      # client.on(:promise) do |promise|
      #   promise.on(:promise_headers) do |h|
      #     Logger[:auto].debug { "promise request headers: #{h}" }
      #   end

      #   promise.on(:headers) do |h|
      #     Logger[:auto].info { "promise headers: #{h}" }
      #   end

      #   promise.on(:data) do |d|
      #     Logger[:auto].info { "promise data chunk: <<#{d.size}>>" }
      #   end
      # end
    end
  end
end
