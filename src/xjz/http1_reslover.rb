module Xjz
  class HTTP1Reslover
    attr_reader :res

    def initialize(req)
      @req = req
      @url = req.url
      body = req.body
      opts = { headers: req.proxy_headers, timeout: $config['proxy_timeout'], follow_redirects: false }
      opts[:body] = body if body.present?
      req_method = req.http_method

      Logger[:request].debug([req_method, @url, opts].inspect)
      @res = HTTParty.send(req_method, @url, opts)
    end

    def response
      @response ||= Response.new(res.headers.to_hash, res.body, res.code)
    end

    def perform
      response.to_rack_response
    end
  end
end
