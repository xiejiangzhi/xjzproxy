module Xjz
  class Request
    attr_reader :env

    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers
    # only for single transport-level connection, must not be retransmitted by proxies or cached
    HOP_BY_HOP = %w{
      connection keep-alive proxy-authenticate proxy-authorization
      te trailers transfer-encoding upgrade
    }
    SHOULD_NOT_TRANSFER = %w{set-cookie proxy-connection}

    def self.new_for_h2(env, headers, buffer)
      env = env.dup
      import_h2_headers_to_env!(env, headers)
      env['rack.input'] = StringIO.new(buffer.is_a?(Array) ? buffer.join : buffer.to_s)
      new(env)
    end

    def initialize(env)
      @env = env
    end

    def http_method
      @http_method ||= env['REQUEST_METHOD'].to_s.downcase
    end

    def host
      @host ||= rack_req.host
    end

    def port
      @port ||= rack_req.port
    end

    def url
      @url ||= rack_req.url
    end

    def path
      @path ||= rack_req.path
    end

    def rack_req
      @rack_req ||= Rack::Request.new(env)
    end

    def user_socket
      env['rack.hijack_io'] || env['rack.hijack'].call
    end

    def headers
      @headers ||= env['xjz.h2_headers'] || env.each_with_object([]) do |kv, r|
        k, v = kv
        next unless k =~ /\AHTTP_\w+/
        k = k[5..-1].downcase.tr('_', '-')
        r << [k, v]
      end
    end

    def proxy_headers
      @proxy_headers ||= begin
        h = headers.dup.delete_if do |k, v|
          HOP_BY_HOP.include?(k) || SHOULD_NOT_TRANSFER.include?(k)
        end
        HTTPHelper.set_header(h, 'content-length', body.bytesize.to_s)
        h
      end
    end

    def body
      @body ||= @env['rack.input'].read
    end

    def protocol
      if env['xjz.h2_headers']
        'http/2.0'
      else
        (env['HTTP_VERSION'] || env['SERVER_PROTOCOL']).downcase
      end
    end

    def content_type
      @content_type ||= rack_req.media_type || get_header('content-type').to_s.split(';').first
    end

    def get_header(name)
      HTTPHelper.get_header(headers, name.to_s)
    end

    def upgrade_flag
      @upgrade_flag ||= begin
        v = get_header('upgrade').to_s.downcase
        !v.empty? ? v : nil
      end
    end

    def scheme
      rack_req.scheme
    end

    private

    def self.import_h2_headers_to_env!(env, headers)
      env['xjz.h2_headers'] = headers
      headers.each_with_object({}) do |line, h2r|
        k, v = line
        k = k.tr('-', '_').upcase

        if k =~ /^:/
          env["H2_#{k[1..-1]}"] = v
        else
          env["HTTP_#{k}"] = v
        end
      end

      env['HTTP_HOST'] ||= env['H2_AUTHORITY']
      env['REQUEST_METHOD'] = env['H2_METHOD'] if env['H2_METHOD']
      if env['H2_PATH']
        path, query = env['H2_PATH'].split('?')
        env['PATH_INFO'] = path
        env['QUERY_STRING'] = query
      end
      env['rack.url_scheme'] = env['H2_SCHEME'] if env['H2_SCHEME']
    end
  end
end
