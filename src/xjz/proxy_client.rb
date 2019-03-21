module Xjz
  class ProxyClient
    attr_reader :client

    def self.h2_test(req)
      res = HTTParty.get(req.url, headers: req.headers)
      res.code == 101
    end

    # protocols: http1, http2
    def initialize(protocol: 'http1')
      @protocol = protocol
      @client = case protocol
      when 'http1' then ProxyClient::HTTP1.new
      when 'http2' then ProxyClient::HTTP2.new
      else
        raise "Invalid proxy client protocol '#{protocol}'"
      end
      Logger[:auto].debug { "New Proxy Client #{protocol}" }
    end

    def send_req(req)
      Logger[:auto].info { " > #{req.http_method} #{req.url.split('?').first} #{@protocol}" }
      tracker = Tracker.track_req(req)
      # TODO call hook before request
      res = hack_req(req) || @client.send_req(req)
      Logger[:auto].info do
        suffix = res.conn_close? ? ' - close' : ''
        " < #{res.code} #{res.body.bytesize} bytes #{suffix}"
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

    def hack_req(req)
      $config['.api_projects'].each do |ap|
        res = ap.hack_req(req)
        return res if res
      end

      nil
    end
  end
end
