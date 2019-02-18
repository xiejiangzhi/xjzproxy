class ProxyRequest
  attr_reader :env, :request, :response

  def initialize(ssl_port:)
    @ssl_port = ssl_port
  end

  def call(env)
    if env['REQUEST_METHOD'] == 'CONNECT'
      [200, {}, ['hello ssl']]
    else
      proxy_request(env)
    end
  end

  def proxy_request(env)
    req = env['rack.request'] || Rack::Request.new(env)
    req_method = req.request_method.to_s.downcase
    headers = fetch_headers(req)

    case req_method
    when 'get', 'head', 'options', 'trace'
      res = HTTParty.send(req_method, req.url, headers: headers)
    when 'post', 'put', 'patch', 'delete'
      res = HTTParty.send(req_method, req.url, headers: headers)
    else
      $logger.error "Cannot proxy: #{req_method} #{req.url}"
      return [500, {}, "Failedto #{req_method} #{req.url}"]
    end

    [res.code, res.headers, [res.body]]
  end

  def fetch_headers(req)
    req.env.each_with_object({}) do |kv, r|
      k, v = kv
      r[k] = v if k =~ /\AHTTP_/
    end
  end
end
