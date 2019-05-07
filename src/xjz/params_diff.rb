module Xjz
  class ParamsDiff
    attr_reader :allow_extend

    def initialize(allow_extend: false)
      @allow_extend = allow_extend
    end

    def diff(expected, actual, index = nil)
      compare_val(expected, actual, index || expected.class.name)
    end

    private

    def compare_val(e, a, prefix = nil, key = nil, r = [])
      index = prefix || e.class.name
      index += "[#{key.inspect}]" if key
      return r if String === key && key[0] == '.' && a.nil?

      case e
      when Array
        if Array === a
          total = allow_extend ? e.size : [e.size, a.size].max
          total.times do |i|
            compare_val(e[i], a[i], index, i, r)
          end
        else
          r << [index, e, a]
        end
      when Hash
        if Hash === a
          keys = allow_extend ? e.keys : (e.keys | a.keys)
          keys.each do |k|
            compare_val(e[k], a[k], index, k, r)
          end
        else
          r << [index, e, a]
        end
      when ApiProject::DataType
        r << [index, e, a] unless e.verify(a)
      else
        r << [index, e, a] unless e == a
      end
      r
    end
  end
end
