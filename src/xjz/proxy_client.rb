module Xjz
  class ProxyClient
    attr_reader :client, :protocol

    def self.auto_new_client(req)
      use_ssl = req.scheme == 'https'
      host, port = req.host, req.port
      pclient = ProxyClient.new(host, port, protocol: 'http2', ssl: use_ssl)

      if use_ssl && pclient.client.remote_sock.alpn_protocol == 'h2'
        Logger[:auto].info { "Connect remote by h2" }
        return [:h2, pclient]
      else
        pclient.close
        pclient = ProxyClient.new(host, port, protocol: 'http2', ssl: use_ssl)
        if pclient.client.ping
          Logger[:auto].info { "Connect remote by h2" }
          return [:h2, pclient]
        else
          pclient.close
          pclient = ProxyClient.new(host, port, protocol: 'http2', ssl: use_ssl, upgrade: true)
          if pclient.client.ping
            Logger[:auto].info { "Connect remote by h2c" }
            return [:h2c, pclient]
          else
            pclient.close
            Logger[:auto].info { "Connect remote by http1" }
            return [:h1, ProxyClient.new(host, port, protocol: 'http1', ssl: use_ssl)]
          end
        end
      end
    end

    # protocols: http1, http2
    def initialize(host, port, protocol: 'http1', ssl: false, upgrade: false)
      @protocol = protocol
      @client = case protocol
      when 'http1' then ProxyClient::HTTP1.new(host, port, ssl: ssl)
      when 'http2' then ProxyClient::HTTP2.new(host, port, ssl: ssl, upgrade: upgrade)
      else
        raise "Invalid proxy client protocol '#{protocol}'"
      end
      Logger[:auto].debug { "New Proxy Client #{protocol}" }
    end

    def send_req(req, &cb)
      Logger[:auto].info { " > #{req.http_method} #{req.url.split('?').first} #{@protocol}" }
      tracker = Tracker.track_req(req)
      # TODO call hook before request
      res = hack_req(req) || @client.send_req(req, &cb)
      if res
        Logger[:auto].info do
          suffix = res.conn_close? ? ' - close' : ''
          " < #{res.code} #{res.body.to_s.bytesize} bytes #{suffix}"
        end
        # TODO call hook after request
        res
      else
        Response.new({}, 'XjzProxy failed to get response', '500')
      end
    ensure
      if tracker
        if res
          tracker.finish(res)
        else
          tracker.finish('error')
        end
      end
    end

    def close
      client.close
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
