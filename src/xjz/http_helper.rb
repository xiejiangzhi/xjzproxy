module Xjz
  class HTTPHelper
    class << self
      def set_header(headers, key, val)
        key = key.to_s
        r = headers.find { |k, v| k == key }
        if r
          r[1] = val
        elsif key[0] == ':'
          headers.unshift([key, val])
        else
          headers << [key, val]
        end
        true
      end

      def get_header(headers, key)
        key = key.to_s.downcase
        (headers.find { |k, v| k.downcase == key } || []).last
      end

      def write_conn_info_to_env!(env, conn)
        if conn.is_a?(OpenSSL::SSL::SSLSocket)
          env['REMOTE_ADDR'] = conn.to_io.remote_address.ip_address
          env['SERVER_PORT'] = (env['SERVER_PORT'] || 443).to_s
          env['rack.url_scheme'] = 'https'
        else
          env['REMOTE_ADDR'] = conn.remote_address.ip_address
          env['SERVER_PORT'] = (env['SERVER_PORT'] || 80).to_s
        end
        env['rack.hijack?'] = true
        env['rack.hijack'] = proc { env['rack.hijack_io'] ||= conn }
        env['rack.hijack_io'] = conn
      end

      def write_res_to_conn(res, conn)
        return if conn.closed?
        conn << res.to_s
        if res.conn_close?
          conn.close
        else
          conn.flush
        end
        Logger[:auto].debug { "Wrote" }
      end
    end
  end
end
