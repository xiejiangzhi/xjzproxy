require 'net/http'
require 'fiber'

class ProxyRequest
  attr_reader :env, :request, :response

  REQ_CLS_MAPPING = %w{
    get head options trace post put patch delete
  }.each_with_object({}) do |name, r|
    r[name] = Net::HTTP.const_get(name[0].upcase + name[1..-1])
  end

  # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers
  # only for single transport-level connection, must not be retransmitted by proxies or cached
  HOP_BY_HOP = %w{
    connection keep-alive proxy-authenticate proxy-authorization
    te trailers transfer-encoding upgrade
  }
  SHOULD_NOT_TRANSFER = %w{set-cookie proxy-connection}

  def initialize(ssl_port:)
    @ssl_port = ssl_port
  end

  def call(env)
    if env['REQUEST_METHOD'] == 'CONNECT'
      [200, {}, ['TODO ssl']]
    else
      proxy_request(env)
    end
  end

  def proxy_request(env)
    req_method = env['REQUEST_METHOD'].to_s.downcase

    case req_method
    when 'get', 'head', 'options', 'trace', 'post', 'put', 'patch', 'delete'
      perform_request(req_method, env).tap { |res| $logger.debug((res[0..1]).inspect) }
    else
      $logger.error "Cannot proxy request: #{env.inspect}"
      return [500, {}, "Failed to #{req_method} #{env['REQUEST_URI']}"]
    end
  end

  def perform_request(req_method, env)
    $logger.debug("#{req_method} #{env['REQUEST_URI']}")
    HTTPRequest.new(req_method, env).to_response
  end

  # def setup_upstream_proxy_authentication(req, res, header)
  #   if upstream = proxy_uri(req, res)
  #     if upstream.userinfo
  #       header['proxy-authorization'] =
  #         "Basic " + [upstream.userinfo].pack("m0")
  #     end
  #     return upstream
  #   end
  #   return FakeProxyURI
  # end

  class HTTPRequest
    attr_reader :fib, :data

    def initialize(req_method, env)
      @env = env
      headers = fetch_req_headers(env)
      url = env['REQUEST_URI']
      body = env['rack.input'].read
      opts = { headers: headers, timeout: $config['proxy_timeout'], stream_body: true }
      opts[:body] = body if body.present?

      @data = []
      @fib = Fiber.new do
        HTTPClient.send(req_method, url, opts) do |f|
          @data << f
          Fiber.yield
        end
      end
    end

    def to_response
      fib.resume
      f = data.first
      headers = process_res_headers(f.http_response.header.to_hash)
      [f.http_response.code, headers, self]
    end

    def each(&block)
      while buf = data.shift do
        break unless buf.is_a?(HTTParty::FragmentWithResponse)
        res_buf = buf.to_s
        $logger.debug("Send #{res_buf.size} bytes for #{@env['REQUEST_URI']}}")
        block.call(res_buf)
        data << fib.resume if fib.alive?
      end
    end

    def fetch_req_headers(env)
      env.each_with_object({}) do |kv, r|
        k, v = kv
        next unless k =~ /\AHTTP_\w+/
        k = k[5..-1].downcase.tr('_', '-')
        next if HOP_BY_HOP.include?(k) || SHOULD_NOT_TRANSFER.include?(k)
        r[k] = v
      end
    end

    def process_res_headers(headers)
      # headers['proxy-connection'] = "close"
      # headers['connection'] = "close"
      headers.delete 'transfer-encoding' # Rack::Chunked will process transfer-encoding
      headers
    end
  end
end
