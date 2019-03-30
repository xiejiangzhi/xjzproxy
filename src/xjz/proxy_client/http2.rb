module Xjz
  class ProxyClient::HTTP2
    attr_reader :client, :host, :port, :use_ssl

    UPGRADE_DATA = <<~REQ
      GET %{path} HTTP/1.1
      Connection: Upgrade, HTTP2-Settings
      HTTP2-Settings: %{settings}
      Upgrade: h2c
      Host: %{host}
      User-Agent: http-2 upgrade
      Accept: */*
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
        cb_stream.call(:headers, h, f)
      end
      stream.on(:data) do |d, f|
        res_buffer << d
        cb_stream.call(:data, d, f)
      end

      stream.on(:close) do
        stop_wait = true
        res = Response.new(res_header, res_buffer)
        cb_stream.call(:close)
      end

      Logger[:auto].debug { "#{req.headers.inspect} #{req.body.inspect}" }

      if req.body.empty?
        stream.headers(req.headers)
      else
        stream.headers(req.headers, end_stream: false)
        stream.data(req.body)
      end
      Logger[:auto].debug { "Sent http2 stream request" }

      IOHelper.forward_streams(
        { remote_sock => WriterIO.new(client) },
        stop_wait_cb: proc { stop_wait }
      )
      res
    end

    def close
      remote_sock.close
    end

    private

    def init_client(client)
      if @upgrade
        remote_socket << UPGRADE_DATA
        raise "TODO parse response"
      end

      client.on(:frame) do |bytes|
        remote_sock << bytes
      end
      client.on(:frame_sent) do |frame|
        Logger[:auto].debug { "-> #{frame.inspect}" }
      end
      client.on(:frame_received) do |frame|
        Logger[:auto].debug { "<- #{frame.inspect}" }
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

    def remote_sock
      @remote_sock ||= begin
        sock = TCPSocket.new(host, port)
        if use_ssl
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.alpn_protocols = %w{h2}
          ssl_sock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
          ssl_sock.hostname = host
          ssl_sock.connect
          ssl_sock
        else
          sock
        end
      end
    end
  end
end
