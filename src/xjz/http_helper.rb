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
    end
  end
end
