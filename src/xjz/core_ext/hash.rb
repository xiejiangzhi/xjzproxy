class Hash
  def stringify_keys
    transform_keys(&:to_s)
  end

  def stringify_keys!
    transform_keys!(&:to_s)
  end

  def deep_transform_keys(&block)
    _deep_transform_keys_in_object(self, &block)
  end

  def deep_transform_keys!(&block)
    _deep_transform_keys_in_object!(self, &block)
  end

  def deep_stringify_keys
    deep_transform_keys(&:to_s)
  end

  def deep_stringify_keys!
    deep_transform_keys!(&:to_s)
  end

  private

  # support methods for deep transforming nested hashes and arrays
  def _deep_transform_keys_in_object(object, &block)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[yield(key)] = _deep_transform_keys_in_object(value, &block)
      end
    when Array
      object.map { |e| _deep_transform_keys_in_object(e, &block) }
    else
      object
    end
  end

  def _deep_transform_keys_in_object!(object, &block)
    case object
    when Hash
      object.keys.each do |key|
        value = object.delete(key)
        object[yield(key)] = _deep_transform_keys_in_object!(value, &block)
      end
      object
    when Array
      object.map! { |e| _deep_transform_keys_in_object!(e, &block) }
    else
      object
    end
  end
end
