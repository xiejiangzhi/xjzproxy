module Xjz
  class ProxyClient::HTTP2
    attr_reader :client

    def initialize
      @client = HTTP2::Client.new
      init_client(client)
    end

    def send_req(req)
      @req = req

      stream = client.new_stream
      res_header = []
      res_buffer = []
      res = nil
      stop_wait = false

      stream.on(:headers) { |h| res_header.push(*h) }
      stream.on(:data) { |d| res_buffer << d }

      stream.on(:close) do
        stop_wait = true
        res = Response.new(res_header, res_buffer)
      end

      if req.body.empty?
        stream.headers(req.headers, end_stream: true)
      else
        stream.headers(req.headers, end_stream: false)
        stream.data(req.body, end_stream: true)
      end
      Logger[:auto].debug { "Sent http2 stream request" }

      IOHelper.forward_streams(
        { remote_sock => WriterIO.new(client) },
        stop_wait_cb: proc { stop_wait }
      )
      res
    end

    private

    def init_client(client)
      client.on(:frame) do |bytes|
        remote_sock << bytes
      end

      # client.on(:frame_sent) do |frame|
      #   Logger[:auto].debug { "Sent #{frame.inspect}" }
      # end

      # client.on(:frame_received) do |frame|
      #   Logger[:auto].debug { "Recv #{frame.inspect}" }
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

    def remote_sock
      @remote_sock ||= begin
        sock = TCPSocket.new(@req.host, @req.port)
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.alpn_protocols = %w{h2 http/1.1}
        ssl_sock = OpenSSL::SSL::SSLSocket.new(sock, ctx)
        ssl_sock.hostname = @req.host
        ssl_sock.connect
        ssl_sock
      end
    end
  end
end
