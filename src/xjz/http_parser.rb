module Xjz
  class HTTPParser
    attr_reader :parser

    HTTP2_ENV = {
      'REQUEST_METHOD' => 'PRI',
      'SCRIPT_NAME' => '',
      'REQUEST_URI' => '*',
      'SERVER_PROTOCOL' => "HTTP/2.0",
      'GATEWAY_INTERFACE' => 'CGI/1.2',
      'SERVER_NAME' => '',
      'SERVER_PORT' => nil,
      'PATH_INFO' => '*',
      'QUERY_STRING' => '',
      'rack.multithread' => true,
      'rack.multiprocess' => false,
      'rack.url_scheme' => 'http'
    }.freeze

    def self.parse_request(conn, &block)
      IO.select([conn], nil, nil, $config['proxy_timeout'])
      data = conn.read_nonblock(HTTP2_REQ_HEADER.bytesize)

      if data.upcase == HTTP2_REQ_HEADER
        env = HTTP2_ENV.dup
        env['rack.input'] = StringIO.new
        env['rack.errors'] = StringIO.new
        HTTPHelper.write_conn_info_to_env!(env, conn)
        block.call(env)
      else
        parser = self.new
        stop_copy = false
        parser.on_finish do |env|
          HTTPHelper.write_conn_info_to_env!(env, conn)
          stop_copy = true
          block.call(env)
        end
        parser << data
        IOHelper.forward_streams(
          { conn => WriterIO.new(parser) },
          stop_wait_cb: proc { stop_copy }
        )
      end
    rescue EOFError
      false
    end

    def self.parse_response(conn, &block)
      headers = {}
      buffers = []
      parser = Http::Parser.new
      parser.on_headers_complete = proc do
        headers = parser.headers.to_a
      end
      parser.on_body = proc do |buffer|
        buffers << buffer
      end
      stop_copy = false
      parser.on_message_complete = proc do
        stop_copy = true
        block.call(parser.status_code, headers, buffers)
      end
      IOHelper.forward_streams(
        { conn => WriterIO.new(parser) },
        stop_wait_cb: proc { stop_copy }
      )
    end

    def initialize
      @parser = Http::Parser.new(self)
    end

    def on_finish(&block)
      raise "Require a block" unless block
      @finish_cb = block
    end

    def <<(data)
      parser << data
    end

    def on_message_begin
      @body = ''
      @env = {}
    end

    def on_headers_complete(headers)
      @env['REQUEST_METHOD'] = parser.http_method
      @env['SCRIPT_NAME'] = ''
      @env['REQUEST_URI'] = parser.request_url
      @env['SERVER_PROTOCOL'] = "HTTP/#{parser.http_version.join('.')}"
      @env['GATEWAY_INTERFACE'] = 'CGI/1.2'

      headers.each do |k, v|
        @env["HTTP_#{k.tr('-', '_').upcase}"] = v
      end

      if @env['REQUEST_METHOD'] == 'CONNECT'
        host, port = parser.request_url.split(':')
        @env['SERVER_NAME'] = host.presence
        @env['SERVER_PORT'] = port.presence
        @env['PATH_INFO'] = ''
        @env['QUERY_STRING'] = ''
      else
        uri = URI.parse(parser.request_url)
        @env['PATH_INFO'] = uri.path
        @env['QUERY_STRING'] = uri.query || ''
        @env['SERVER_NAME'] = (uri.host || @env['HTTP_HOST']).presence
        @env['SERVER_PORT'] = uri.port.presence
      end
    end

    def on_body(chunk)
      @body << chunk
    end

    def on_message_complete
      @env['rack.input'] = StringIO.new @body
      @env['rack.errors'] = StringIO.new
      @env['rack.multithread'] = true
      @env['rack.multiprocess'] = false
      @env['rack.url_scheme'] = 'http'
      @finish_cb.call(@env)
    end
  end
end
