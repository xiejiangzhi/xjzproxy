module Xjz
  class ProxyClient::HTTP1
    attr_reader :client, :last_raw_res, :use_ssl, :upgrade

    def initialize(host, port, ssl: false, upgrade: false)
      @host, @port = host, port.to_i
      @client = new_client
      @use_ssl = ssl
      @upgrade = false
    end

    def send_req(req, &cb)
      r = nil

      Logger[:auto].debug { "Send HTTP1 request #{[req.http_method, req.url].inspect}" }
      res = @client.send(req.http_method, req.url) do |fr|
        fr.options.timeout = $config['proxy_timeout']
        fr.headers = req.h1_proxy_headers
        fr.body = req.body if req.body.present?
      end
      r = Response.new(res.headers.to_hash, res.body, res.status)
    ensure
      cb.call(:close, r) if cb
    end

    def close; end
    def closed?; end
    def wait_finish; end

    private

    def new_client
      Faraday.new do |f|
        if Gem.win_platform?
          f.adapter Faraday.default_adapter
        else
          f.adapter :net_http_persistent, pool_size: 3 do |http|
            http.idle_timeout = 100
            http.retry_change_requests = true
          end
        end
      end
    end
  end
end
