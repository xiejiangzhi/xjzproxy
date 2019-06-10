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
      @mutex = Mutex.new
      @conn_thread = nil
      @closed = nil
      init_client(@client)
    end

    def ping
      return false if closed?
      v = []
      client.ping('a' * 8) { v << 1 }
      wake_up_conn_forwarder
      wait_to { v.present? || closed? }
      v.present?
    rescue Errno::EPROTOTYPE => e
      Logger[:auto].error { e.message }
      false
    end

    def send_req(req, &stream_cb)
      return if closed?
      stream = @mutex.synchronize { client.new_stream }
      res_header = []
      res_buffer = []
      rdata = []

      stream.on(:headers) do |h, f|
        res_header.push(*h)
        stream_cb.call(:headers, h, f) if stream_cb
      end
      stream.on(:data) do |d, f|
        res_buffer << d
        stream_cb.call(:data, d, f) if stream_cb
      end
      stream.on(:close) do
        Logger[:auto].debug { "Stream #{req.path} close" }
        rdata << Response.new(res_header, res_buffer)
      ensure
        stream_cb.call(:close, rdata.first) if stream_cb
      end

      Logger[:auto].debug { "New proxy stream #{stream.id} for #{req.url}" }
      if req.body.empty?
        stream.headers(req.headers, end_stream: true)
      else
        stream.headers(req.headers, end_stream: false)
        stream.data(req.body)
      end

      wake_up_conn_forwarder

      unless stream_cb
        wait_to { rdata.present? || closed? }
        rdata.first
      end
    end

    def close
      return if @closed
      Logger[:auto].info { "Close remote socket" }
      @closed = true
      @conn_thread.kill if @conn_thread && @conn_thread.alive? && @conn_thread != Thread.current
      @remote_sock&.close
    end

    def closed?
      @closed || !remote_sock || remote_sock.closed?
    end

    def wait_finish
      @conn_thread&.join
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
    rescue SocketError, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
      Logger[:auto].error { e.message }
      @closed = true
      nil
    end

    private

    def init_client(client)
      return if closed?
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
          unless closed?
            remote_sock << bytes
            remote_sock.flush
          end
        rescue Errno::EPIPE => e
          Logger[:auto].error { e.message }
          close
        end
      end

      client.on(:goaway) do
        Logger[:auto].debug { "Remote server goaway" }
        close
      end

      client.on(:frame_sent) do |frame|
        Logger[:auto].debug { "-> #{frame.except(:payload).inspect}" }
      end
      client.on(:frame_received) do |frame|
        Logger[:auto].debug { "<- #{frame.except(:payload).inspect}" }
      end

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

    def wait_to(&block)
      interval = 0.1
      ($config['proxy_timeout'] / interval).to_i.times do
        break if block.call
        sleep interval
      end
    end

    def wake_up_conn_forwarder
      return if @conn_thread
      return if closed?

      @mutex.synchronize do
        @conn_thread = Thread.new do
          IOHelper.forward_streams(remote_sock => WriterIO.new(@client))
        ensure
          close
        end
      end
    end
  end
end
