require 'socket'
require 'openssl'

class SSLProxy
  attr_reader :cert_gen

  def initialize(app)
    @app = app
    @http_proxy_host = "http://0.0.0.0:#{$config['proxy_port']}"
  end

  def call(env)
    if env['REQUEST_METHOD'] == 'CONNECT'
    else
      @app.call(env)
    end
  end

  private

  def connect_proxy
    host, port = req.unparsed_uri.split(":", 2)
    # Proxy authentication for upstream proxy server
    if proxy = proxy_uri(req, res)
      proxy_request_line = "CONNECT #{host}:#{port} HTTP/1.0"
      if proxy.userinfo
        credentials = "Basic " + [proxy.userinfo].pack("m0")
      end
      host, port = proxy.host, proxy.port
    end

    begin
      @logger.debug("CONNECT: upstream proxy is `#{host}:#{port}'.")
      os = TCPSocket.new(host, port)     # origin server

      if proxy
        @logger.debug("CONNECT: sending a Request-Line")
        os << proxy_request_line << CRLF
        @logger.debug("CONNECT: > #{proxy_request_line}")
        if credentials
          @logger.debug("CONNECT: sending credentials")
          os << "Proxy-Authorization: " << credentials << CRLF
        end
        os << CRLF
        proxy_status_line = os.gets(LF)
        @logger.debug("CONNECT: read Status-Line from the upstream server")
        @logger.debug("CONNECT: < #{proxy_status_line}")
        if %r{^HTTP/\d+\.\d+\s+200\s*} =~ proxy_status_line
          while line = os.gets(LF)
            break if /\A(#{CRLF}|#{LF})\z/om =~ line
          end
        else
          raise HTTPStatus::BadGateway
        end
      end
      @logger.debug("CONNECT #{host}:#{port}: succeeded")
      res.status = HTTPStatus::RC_OK
    rescue => ex
      @logger.debug("CONNECT #{host}:#{port}: failed `#{ex.message}'")
      res.set_error(ex)
      raise HTTPStatus::EOFError
    ensure
      if handler = @config[:ProxyContentHandler]
        handler.call(req, res)
      end
      res.send_response(ua)
      access_log(@config, req, res)

      # Should clear request-line not to send the response twice.
      # see: HTTPServer#run
      req.parse(NullReader) rescue nil
    end
  end
end
