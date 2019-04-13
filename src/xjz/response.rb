require 'zlib'

module Xjz
  class Response
    attr_reader :raw_headers, :raw_body

    def initialize(raw_headers, raw_body, code = nil)
      @code = code
      @raw_headers = raw_headers
      @raw_body = raw_body
      @http2 = if raw_headers.empty?
        false
      else
        (raw_headers.is_a?(Hash) ? raw_headers.keys[0][0] : raw_headers[0][0][0]) == ':'
      end
      @conn_status = 'keep-alive'
    end

    def h1_headers
      @h1_headers ||= format_res_headers.first
    end

    def h2_headers
      @h2_headers ||= format_res_headers.last
    end

    def code
      @code ||= (format_res_headers && @code).to_i
    end

    def body
      @body ||= case raw_body
      when Array then raw_body.join
      else raw_body.to_s
      end
    end

    def content_type
      @content_type ||= (HTTPHelper.get_header(h1_headers, 'content-type') || 'text/plain').downcase
    end

    def content_encoding
      @content_encoding ||= (HTTPHelper.get_header(h1_headers, 'content-encoding') || 'identity').downcase
    end

    def decoded_body
      @decoded_body ||= case content_encoding
      when 'gzip'
        ActiveSupport::Gzip.decompress(body)
      when 'deflate'
        Zlib::Inflate.inflate(body)
      else
        body
      end
    end

    def to_rack_response
      [code, h1_headers, [body].compact]
    end

    def conn_close?
      @conn_status == 'close'
    end

    def protocol
      @http2 ? 'http/2.0' : (raw_headers['version'] || 'http/1.1').downcase
    end

    # http/1.1
    def to_s
      str = "HTTP/1.1 #{code} #{HTTP_STATUS_CODES[code] || 'CUSTOM'}\r\n"
      h1_headers.each do |k, v|
        str << "#{k}: #{v}\r\n"
      end
      str << LINE_END << body
    end

    private

    def format_res_headers
      h1, h2, keys = [], [], []

      raw_headers.each do |k, v|
        k = k.downcase
        keys << k
        line = [k, v.is_a?(Array) ? v.join(', ') : v.to_s]

        case k
        when 'transfer-encoding'
          # ignore
        when ':status'
          # http2 headers only
          @code = v.to_i
          @http2 = true
          h2 << line
        when 'connection'
          # http1 headers only
          @conn_status = (v.is_a?(Array) ? v.first : v).downcase
          h1 << line
        else
          h1 << line
          h2 << line
        end
      end

      @code ||= 200
      h2.unshift([':status', @code.to_s]) unless keys.include?(':status')
      body_size = body.bytesize.to_s
      [h1, h2].each do |h|
        HTTPHelper.set_header(h, 'content-length', body_size)
      end
      [@h1_headers = h1, @h2_headers = h2]
    end
  end
end
