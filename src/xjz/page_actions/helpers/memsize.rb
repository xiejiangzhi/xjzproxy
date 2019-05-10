require 'objspace'

module Xjz
  module Helper::Memsize
    extend self

    def count(obj)
      obj.instance_eval do
        ObjectSpace.memsize_of(obj) +
          instance_variables.map do |name|
            v = instance_variable_get(name)

            case v
            when Hash, Array
              v.to_a.flatten.map { |a| ObjectSpace.memsize_of(a) }.sum
            else
              0
            end + ObjectSpace.memsize_of(v)
          end.sum
      end
    end
  end
end
