module Xjz
  class ProxyClient::HTTP1
    attr_reader :client, :last_raw_res, :use_ssl, :upgrade

    def initialize(host, port, ssl: false, upgrade: false)
      @host, @port = host, port
      @client = HTTParty
      @use_ssl = ssl
      @upgrade = false
    end

    def send_req(req, &cb)
      r = nil
      opts = {
        headers: req.h1_proxy_headers,
        timeout: $config['proxy_timeout'],
        follow_redirects: false
      }
      opts[:body] = req.body if req.body.present?

      Logger[:auto].debug { "Send http1 request #{}" }
      Logger[:auto].debug { [req.http_method, req.url, opts].inspect }
      res = @client.send(req.http_method, req.url, opts)
      r = Response.new(res.headers.to_hash, res.body, res.code)
    ensure
      cb.call(:close, r) if cb
    end

    def close; end
    def closed?; end
    def wait_finish; end
  end
end
