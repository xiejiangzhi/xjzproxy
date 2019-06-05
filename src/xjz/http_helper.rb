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
        proxy_host, proxy_port = if conn.respond_to?(:proxy_host)
          [conn.proxy_host, conn.proxy_port]
        end

        case conn
        when OpenSSL::SSL::SSLSocket
          env['REMOTE_ADDR'] ||= conn.to_io.remote_address.ip_address
          env['SERVER_NAME'] = env['SERVER_NAME'].presence || proxy_host || ''
          env['SERVER_PORT'] = (env['SERVER_PORT'].presence || proxy_port || 443).to_s
          env['rack.url_scheme'] = 'https'
        else
          env['REMOTE_ADDR'] ||= conn.remote_address.ip_address
          env['SERVER_NAME'] = env['SERVER_NAME'].presence || proxy_host || ''
          env['SERVER_PORT'] = (env['SERVER_PORT'].presence || proxy_port || 80).to_s
        end

        unless env['rack.hijack?']
          env['rack.hijack?'] = true
          env['rack.hijack'] = proc { env['rack.hijack_io'] ||= conn }
          env['rack.hijack_io'] = conn
        end
      end

      def write_res_to_conn(res, conn)
        return if conn.closed?
        data = res.to_s
        conn << data
        if res.conn_close?
          conn.close
        else
          conn.flush
        end
        Logger[:auto].debug { "Wrote res #{data.bytesize} bytes" }
      end

      # schema: it is required if data need a schema to parse
      def parse_data_by_type(data, content_type, schema = nil)
        type = case content_type
        when /json/i then :json
        when /xml/i then :xml
        when /x-www-form-urlencoded/i, 'urlencoded' then :url
        when /application\/grpc/i, 'urlencoded' then :grpc
        else
          d = data.strip
          case d
          when '' then :empty
          when /\A[\{\[].*[\}\]]\z/m then :json
          when /\A<.*\/html>\z/im then :text
          when /\A<.*>\z/m then :xml
          when /=/ then :url
          end
        end

        case type
        when :empty then {}
        when :json then JSON.parse(data)
        when :xml then Hash.from_xml(data)
        when :url then Rack::Utils.parse_query(data)
        when :grpc
          if schema
            data.force_encoding('binary')
            _compressed, length = data[0..4].unpack('CN')
            pb = schema.decode(data.slice(5, length))
            pb.to_hash.deep_stringify_keys
          else
            Logger[:auto].error { "Need a schema to parse GRPC data" }
            {}
          end
        else
          Logger[:auto].error { "Cannot parse #{content_type.inspect} #{data.inspect}" }
          {}
        end
      rescue => e
        Logger[:auto].error { "Failed to parse #{content_type.inspect} #{data.inspect}" }
        Logger[:auto].error { e.log_inspect }
        {}
      end
    end
  end
end
