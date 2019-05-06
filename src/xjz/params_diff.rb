module Xjz
  class ParamsDiff
    def initialize
    end

    def diff(expected, actual, index = nil)
      compare_val(expected, actual, index || expected.class.name)
    end

    private

    def compare_val(e, a, index = nil, r = [])
      index ||= e.class.name
      case e
      when ApiProject::DataType
        r << [index, e, a] unless e.verify(a)
      when Array
        if Array === a
          [e.size, a.size].max.times do |i|
            compare_val(e[i], a[i], "#{index}[#{i}]", r)
          end
        else
          r << [index, e, a]
        end
      when Hash
        if Hash === a
          keys = e.keys | a.keys
          keys.each do |k|
            compare_val(e[k], a[k], "#{index}[#{k.inspect}]", r)
          end
        else
          r << [index, e, a]
        end
      else
        r << [index, e, a] unless e == a
      end
      r
    end
  end
end
