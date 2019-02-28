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
      HTTP1Response.new(req_method, env).to_response.tap do |res|
        AppLogger[:proxy].debug "Response: #{(res[0..1]).inspect}" unless env['REQUEST_PATH'] == '/favicon.ico'
      end
    when 'pri'
      HTTP2Response.new(env).to_response
    else
      AppLogger[:proxy].error "Cannot proxy request: #{env.inspect}"
      return [500, {}, "Failed to #{req_method} #{env['xjz.url']}"]
    end
  end
end
