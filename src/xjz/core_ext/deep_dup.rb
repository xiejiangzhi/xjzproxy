class Object
  def deep_dup
    duplicable? ? dup : self
  end
end

class Array
  def deep_dup
    map(&:deep_dup)
  end
end

class Hash
  def deep_dup
    hash = dup
    each_pair do |key, value|
      if key.frozen? && ::String === key
        hash[key] = value.deep_dup
      else
        hash.delete(key)
        hash[key.deep_dup] = value.deep_dup
      end
    end
    hash
  end
end

class Object
  def duplicable?
    true
  end
end

class NilClass
  begin
    nil.dup
  rescue TypeError
    def duplicable?
      false
    end
  end
end

class FalseClass
  begin
    false.dup
  rescue TypeError
    def duplicable?
      false
    end
  end
end

class TrueClass
  begin
    true.dup
  rescue TypeError
    def duplicable?
      false
    end
  end
end

class Symbol
  begin
    :symbol.dup
    "symbol_from_string".to_sym.dup
  rescue TypeError
    def duplicable?
      false
    end
  end
end

class Numeric
  begin
    1.dup
  rescue TypeError
    def duplicable?
      false
    end
  end
end

class Method
  def duplicable?
    false
  end
end

class Complex
  begin
    Complex(1).dup
  rescue TypeError
    def duplicable?
      false
    end
  end
end

class Rational
  begin
    Rational(1).dup
  rescue TypeError
    def duplicable?
      false
    end
  end
end
