module Xjz
  class HTTPParser
    attr_reader :parser

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
        @env['SERVER_NAME'] = host
        @env['SERVER_PORT'] = (port || 443).to_s
        @env['PATH_INFO'] = ''
        @env['QUERY_STRING'] = ''
      else
        uri = URI.parse(parser.request_url)
        @env['PATH_INFO'] = uri.path
        @env['QUERY_STRING'] = uri.query || ''
        @env['SERVER_NAME'] = uri.host || @env['HTTP_HOST']
        @env['SERVER_PORT'] = (uri.port || '80').to_s
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
