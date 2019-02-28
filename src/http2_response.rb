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
    @remote_conn = nil
    @proxy_client
  end

  def to_response
    @resolver_server << HTTP2_REQ_DATA
    RequestHelper.forward_streams(@user_conn => HTTP2Stream.new(@resolver_server))
    AppLogger[:http2_proxy].debug("Finished")
    [200, { 'content-length' => 0 }, []]
  end



  def init_h2_resolver
    conn = HTTP2::Server.new
    user_conn = @user_conn
    conn.on(:frame) do |bytes|
      user_conn.write(bytes)
      AppLogger[:http2_proxy].debug "end frame"
    end

    conn.on(:stream) do |stream|
      header = []
      buffer = []
      stream.on(:headers) do |h|
        header.push(*h)
        AppLogger[:http2_proxy].debug "request headers: #{h}"
      end

      stream.on(:data) do |d|
        buffer << d
        AppLogger[:http2_proxy].debug "request data: #{d}"
      end

      stream.on(:half_close) do
        response = 'hello'

        stream.headers({
          ':status' => '200',
          'content-length' => response.bytesize.to_s,
          'content-type' => 'text/plain',
        }, end_stream: false)

        stream.data(response)
        AppLogger[:http2_proxy].debug "end_stream"
      end
    end
    conn
  end

  def create_remote_conn
    conn = HTTP2::Client.new
    stream = conn.new_stream

    conn.on(:frame) do |bytes|
      # puts "Sending bytes: #{bytes.unpack("H*").first}"
      sock.print bytes
      sock.flush
    end
    conn.on(:frame_sent) do |frame|
      AppLogger[:http2_proxy].debug "Sent frame: #{frame.inspect}"
    end
    conn.on(:frame_received) do |frame|
      AppLogger[:http2_proxy].debug "Received frame: #{frame.inspect}"
    end

    conn.on(:promise) do |promise|
      promise.on(:promise_headers) do |h|
        AppLogger[:http2_proxy].debug "promise request headers: #{h}"
      end

      promise.on(:headers) do |h|
        AppLogger[:http2_proxy].info "promise headers: #{h}"
      end

      promise.on(:data) do |d|
        AppLogger[:http2_proxy].info "promise data chunk: <<#{d.size}>>"
      end
    end

    conn.on(:altsvc) do |f|
      AppLogger[:http2_proxy].info "received ALTSVC #{f}"
    end

    stream.on(:close) do
      AppLogger[:http2_proxy].info 'stream closed'
    end

    stream.on(:half_close) do
      AppLogger[:http2_proxy].info 'closing client-end of the stream'
    end

    stream.on(:headers) do |h|
      AppLogger[:http2_proxy].info "response headers: #{h}"
    end

    stream.on(:data) do |d|
      AppLogger[:http2_proxy].info "response data chunk: <<#{d}>>"
    end

    stream.on(:altsvc) do |f|
      AppLogger[:http2_proxy].info "received ALTSVC #{f}"
    end

    conn
  end

  # def proxy_local_request(local_sock, server_sock)
  #   RequestHelper.forward_streams(
  #     local_sock => server_sock,
  #     server_sock => local_sock
  #   )
  # ensure
  #   local_sock.close rescue nil
  #   server_sock.close rescue nil
  # end

  # def proxy_remote_request(env)
  #   head = {
  #     ':scheme' => uri.scheme,
  #     ':method' => (options[:payload].nil? ? 'GET' : 'POST'),
  #     ':authority' => [uri.host, uri.port].join(':'),
  #     ':path' => uri.path,
  #     'accept' => '*/*',
  #   }

  #   puts 'Sending HTTP 2.0 request'
  #   if head[':method'] == 'GET'
  #     stream.headers(head, end_stream: true)
  #   else
  #     stream.headers(head, end_stream: false)
  #     stream.data(options[:payload])
  #   end

  #   while !sock.closed? && !sock.eof?
  #     data = sock.read_nonblock(1024)
  #     # puts "Received bytes: #{data.unpack("H*").first}"

  #     begin
  #       conn << data
  #     rescue StandardError => e
  #       puts "#{e.class} exception: #{e.message} - closing socket."
  #       e.backtrace.each { |l| puts "\t" + l }
  #       sock.close
  #     end
  #   end
  # end

end
