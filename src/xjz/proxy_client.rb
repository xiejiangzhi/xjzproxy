module Xjz
  class ProxyClient
    attr_reader :client, :protocol, :api_project

    ERR_RES = {
      default: [{}, "#{$app_name} failed to get response", 500],
      timeout: [{}, "#{$app_name} get response expired", 504],
      addr: [{}, "#{$app_name} nodename nor servname provided, or not known", 500],
    }

    def self.auto_new_client(req, ap = nil)
      r = new_by_api_project(req, ap) if ap
      return r if r
      host, port = req.host, req.port
      upgrade = req.upgrade_flag ? true : false
      use_ssl = req.scheme == 'https'
      opts = { ssl: use_ssl, api_project: ap, upgrade: upgrade }

      pclient = ProxyClient.new(host, port, opts.merge(protocol: 'http2'))
      if use_ssl && pclient.client.remote_sock&.alpn_protocol == 'h2'
        Logger[:auto].info { "Connect remote by h2" }
        return [:h2, pclient]
      elsif pclient.client.ping
        name = upgrade ? :h2c : :h2
        Logger[:auto].info { "Connect remote by #{name}" }
        return [name, pclient]
      else
        pclient.close
        Logger[:auto].info { "Connect remote by http1" }
        return [:h1, ProxyClient.new(host, port, opts.merge(protocol: 'http1'))]
      end
    end

    # protocols: http1, http2
    def initialize(host, port, protocol: 'http1', ssl: false, upgrade: false, api_project: nil)
      @api_project = api_project
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
      Xjz.LICENSE_CHECK() if rand(1000) == 0
      tracker = Tracker.track_req(req, api_project: api_project)
      res = fetch_res(req, cb)

      Logger[:auto].info do
        suffix = res.conn_close? ? ' - close' : ''
        " < #{res.code} #{res.body.to_s.bytesize} bytes #{suffix}"
      end
      res
    ensure
      res ? tracker.finish(res) : tracker.error('error') if tracker
    end

    def close
      client.close
    end

    private

    def self.new_by_api_project(req, ap)
      host, port = req.host, req.port
      upgrade = req.upgrade_flag ? true : false
      protocol = ap.data['project']['protocol']
      use_ssl = ap.data['project']['ssl'] ? true : false
      return unless protocol || ap.grpc

      pname = ap.grpc ? (protocol || 'http2') : protocol
      return unless pname

      c = ProxyClient.new(host, port, protocol: pname, ssl: use_ssl, upgrade: upgrade, api_project: ap)
      case pname
      when 'http1'
        [:h1, c]
      when 'http2'
        [use_ssl ? :h2 : :h2c, c]
      else
        raise "Unsupported protocol #{pname}"
      end
    end

    def fetch_res(req, cb)
      res = api_project&.hack_req(req)
      if res
        process_res_callback(res, cb) if cb
        res
      else
        @client.send_req(req, &cb) || Response.new(*ERR_RES[:default])
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Logger[:auto].error { e.message }
      Response.new(*ERR_RES[:timeout])
    rescue OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, SocketError => e
      Logger[:auto].error { e.message }
      msg = e.message
      if msg.start_with?('getaddrinfo')
        Response.new(*ERR_RES[:addr])
      elsif msg.start_with?('Timeout')
        Response.new(*ERR_RES[:timeout])
      else
        Response.new(*ERR_RES[:default])
      end
    end

    def process_res_callback(res, cb)
      if api_project.grpc
        cb.call(:headers, res.h2_headers, [])
        cb.call(:data, res.body, [])
        cb.call(:headers, [['grpc-status', '0'], ['grpc-message', 'OK']], [:end_headers, :end_stream])
        cb.call(:close)
      else
        cb.call(:headers, res.body, [:end_headers])
        cb.call(:data, res.body, [:end_stream])
        cb.call(:close)
      end
    end
  end
end
