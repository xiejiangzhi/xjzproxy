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
        if conn.is_a?(OpenSSL::SSL::SSLSocket)
          env['REMOTE_ADDR'] = conn.to_io.remote_address.ip_address
          env['rack.url_scheme'] = 'https'
        else
          env['REMOTE_ADDR'] = conn.remote_address.ip_address
        end
        env['rack.hijack?'] = true
        env['rack.hijack'] = proc { env['rack.hijack_io'] ||= conn }
        env['rack.hijack_io'] = conn
      end

      def write_res_to_conn(res, conn)
        status = res.code
        headers = []
        headers << ["HTTP/1.1", status, HTTP_STATUS_CODES[status] || 'CUSTOM'].join(' ')
        res.h1_headers.each do |k, v|
          headers << "#{k}: #{v}"
        end
        conn << (headers.join(LINE_END) + "\r\n\r\n")

        unless res.body.empty?
          conn << res.body
        end
      end
    end
  end
end
