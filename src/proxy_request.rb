require 'net/http'
require 'fiber'

class ProxyRequest
  attr_reader :env, :request, :response, :ssl_server

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

  def call(env)
    req_method = env['REQUEST_METHOD'].to_s.downcase

    case req_method
    when 'get', 'head', 'options', 'trace', 'post', 'put', 'patch', 'delete'
      HTTPRequest.new(req_method, env).to_response.tap do |res|
        AppLogger[:proxy].debug "Response: #{(res[0..1]).inspect}" unless env['REQUEST_PATH'] == '/favicon.ico'
      end
    else
      AppLogger[:proxy].error "Cannot proxy request: #{env.inspect}"
      return [500, {}, "Failed to #{req_method} #{env['xjz.url']}"]
    end
  end

  class HTTPRequest
    attr_reader :res

    def initialize(req_method, env)
      @env = env
      @url = env['xjz.url']
      headers = fetch_req_headers(@env)
      env['xjz.req_headers'] = headers
      body = @env['rack.input'].read
      opts = { headers: headers, timeout: $config['proxy_timeout'] }
      opts[:body] = body if body.present?

      AppLogger[:request].debug([req_method, @url, opts].inspect)
      @res = HTTParty.send(req_method, @url, opts)
    end

    def to_response
      headers = process_res_headers(res.header.to_hash)
      Rack::Response.new([res.body], res.code, headers).finish
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
