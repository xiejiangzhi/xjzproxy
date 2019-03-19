module Xjz
  class ProxyClient
    attr_reader :client

    def self.h2_test(req)
      res = HTTParty.get(req.url, headers: req.headers)
      res.code == 101
    end

    # protocols: http1, http2
    def initialize(protocol: 'http1')
      @client = case protocol
      when 'http1' then ProxyClient::HTTP1.new
      when 'http2' then ProxyClient::HTTP2.new
      else
        raise "Invalid proxy client protocol '#{protocol}'"
      end
    end

    def send_req(req)
      Logger[:auto].info { "Start #{req.http_method} #{req.url.split('?').first}" }
      tracker = Tracker.track_req(req)
      # TODO call hook before request
      res = @client.send_req(req)
      Logger[:auto].info do
        "Done #{req.http_method} #{req.url.split('?').first} < #{res.code} #{res.body.bytesize}"
      end
      # TODO call hook after request
      res
    ensure
      if tracker
        if res
          tracker.finish(res)
        else
          tracker.finish('error')
        end
      end
    end
  end
end
