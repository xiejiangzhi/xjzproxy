module Xjz
  module HTTPHelper
    extend self

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
