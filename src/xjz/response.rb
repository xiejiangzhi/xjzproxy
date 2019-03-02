module Xjz
  class Response
    attr_reader :raw_headers, :raw_body

    def initialize(raw_headers, raw_body, code = nil)
      @code = code
      @raw_headers = raw_headers
      @raw_body = raw_body
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
      when nil then nil
      when Array then raw_body.join
      else raw_body.to_s
      end
    end

    def to_rack_response
      [code, h1_headers, [body].compact]
    end

    private

    def format_res_headers
      h1, h2, keys = [], [], []

      raw_headers.each do |k, v|
        keys << k
        line = [k, v.is_a?(Array) ? v.join(', ') : v.to_s]

        case k
        when 'transfer-encoding'
          # ignore
        when ':status'
          # http2 headers only
          @code = v.to_i
          h2 << line
        when 'connection'
          # http1 headers only
          h1 << line
        else
          h1 << line
          h2 << line
        end
      end

      h2.unshift([':status', code.to_s]) unless keys.include?(':status')
      body_size = body.bytesize.to_s
      [h1, h2].each do |h|
        update_headers!(h, 'content-length', body_size)
      end
      [@h1_headers = h1, @h2_headers = h2]
    end

    def update_headers!(headers, key, val)
      r = headers.find { |k, v| k == key }
      if r
        r[1] = val
      elsif key[0] == ':'
        headers.unshift([key, val])
      else
        headers << [key, val]
      end
    end
  end
end
