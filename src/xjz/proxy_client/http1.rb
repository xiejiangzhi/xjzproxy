module Xjz
  class ProxyClient::HTTP1
    attr_reader :client, :last_raw_res

    def initialize
      @client = HTTParty
      @last_raw_res = nil
    end

    def send_req(req)
      opts = {
        headers: req.proxy_headers,
        timeout: $config['proxy_timeout'],
        follow_redirects: false
      }
      opts[:body] = req.body if req.body.present?

      res = @last_raw_res = @client.send(req.http_method, req.url, opts)
      Response.new(res.headers.to_hash, res.body, res.code)
    end
  end
end
