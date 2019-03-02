module Xjz
  class Reslover::HTTP1
    attr_reader :res, :req

    def initialize(req)
      @req = req
      @res = nil

      proxy_request
    end

    def response
      @response ||= Response.new(res.headers.to_hash, res.body, res.code)
    end

    def perform
      response.to_rack_response
    end

    private

    def proxy_request
      url = req.url
      body = req.body
      opts = {
        headers: req.proxy_headers,
        timeout: $config['proxy_timeout'],
        follow_redirects: false
      }
      opts[:body] = body if body.present?
      req_method = req.http_method

      tracker = Tracker.track_req(req)
      @res = HTTParty.send(req_method, url, opts)
      tracker.finish(response)
    end
  end
end
