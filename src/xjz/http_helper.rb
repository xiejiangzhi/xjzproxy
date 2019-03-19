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
        key = key.to_s
        (headers.find { |k, v| k == key } || []).last
      end

      def write_conn_info_to_env!(env, conn)
        env['REMOTE_ADDR'] = conn.remote_address.ip_address
        env['rack.hijack?'] = true
        env['rack.hijack'] = proc { env['rack.hijack_io'] ||= conn }
        env['rack.hijack_io'] = conn
      end

      def write_res_to_http1_conn(res, conn)
      end
    end
  end
end
