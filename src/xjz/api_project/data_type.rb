module Xjz
  module Boolean; end
  TrueClass.include Boolean
  FalseClass.include Boolean

  class ApiProject::DataType
    attr_reader :raw_data, :counter

    TYPES_MAPPING = {
      integer: proc { 1 + rand(9999999999) },
      float: proc { (rand * 999999).round(3) },
      string: proc { Faker::Alphanumeric.alpha(64) },
      text: proc { Faker::Lorem.paragraph },
      boolean: proc { rand < 0.5 },

      name: proc { Faker::Name.name },
      email: proc { Faker::Internet.email },
      avatar: proc { Faker::Avatar.image },
      username: proc { Faker::Internet.username },
      hex_color: proc { Faker::Color.hex_color },
      color_name: proc { Faker::Color.color_name },
      domain: proc { Faker::Internet.domain_name },
      url: proc { Faker::Internet.url },
      date: proc { Time.at(Time.now.to_i + rand(2000000) - 1000000).strftime('%F') },
      datetime: proc { Time.at(Time.now.to_i + rand(2000000) - 1000000).strftime('%F %T') },
      markdown: proc { Faker::Markdown.sandwich }
    }.stringify_keys

    def self.default_types
      @default_types ||= TYPES_MAPPING.each_with_object({}) do |kv, r|
        name, block = kv
        r[name.to_s] = new('type' => name.to_s, 'builder' => block)
      end
    end

    # raw_data:
    #   type:
    #   items:
    #   prefix:
    #   suffix:
    #   regexp:
    #   builder:
    #   validator:
    def initialize(raw_data)
      @raw_data = raw_data
      @regexp = @raw_data['regexp'].present? ? Regexp.new(@raw_data['regexp']) : nil

      @validator = @raw_data['validator']
      @builder = @raw_data['builder']

      @counter = 0
      @mutex = Mutex.new
    end

    def name
      @raw_data['type']
    end

    def validator
      @validator ||= if raw_data['regexp']
        Regexp.new(raw_data['regexp'])
      else
        val = generate
        cls = val.class
        Boolean === val ? Boolean : cls
      end
    end

    def builder
      # create custom builder
      @builder ||= if raw_data['items'] || raw_data['regexp']
        method(:gen_by_config)
      else
        raise "Invalid type config"
      end
    end

    def verify(val)
      case validator
      when Proc
        validator.call(val)
      when Regexp
        validator.match?(val)
      else
        validator === val
      end
    end

    def generate
      r = incr_counter
      builder.call(r)
    end

    def inspect
      "#<#{self.class.name} #{name}>"
    end

    def to_json(*args)
      ".t/#{name}"
    end

    private

    def incr_counter
      @mutex.synchronize { @counter += 1 }
    end

    def gen_by_config(counter)
      val = if @regexp
        begin
          @regexp.random_example
        rescue => e
          Logger[:auto].error { e.log_inspect }
          return "Failed to build string by #{@regexp.inspect}"
        end
      else
        Array.wrap(raw_data['items'] || []).sample
      end

      val = Array.wrap(raw_data['prefix']).sample.to_s + val.to_s if raw_data['prefix']
      val = val.to_s + Array.wrap(raw_data['suffix']).sample.to_s if raw_data['suffix']
      (val.is_a?(String) && val['%']) ? (val % { i: counter }) : val
    end
  end
end
