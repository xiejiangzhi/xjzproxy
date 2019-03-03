module Xjz
  class ProxyClient
    attr_reader :client

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
      tracker = Tracker.track_req(req)
      @client.send_req(req).tap do |res|
        tracker.finish(res)
      end
    end
  end
end
