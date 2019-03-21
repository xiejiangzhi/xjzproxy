module Xjz
  class ApiProject::DataType
    attr_reader :raw_data, :counter

    TYPES_MAPPING = {
      integer: proc { 1 + rand(9999999999) },
      float: proc { (rand * 999999).round(3) },
      string: proc { Faker::Alphanumeric.alpha(64) },
      text: proc { Faker::Lorem.paragraph },
      boolean: proc { rand < 0.5 },
      date: proc { Time.at(Time.now.to_i + rand(2000000) - 1000000).to_date },
      datetime: proc { Time.at(Time.now.to_i + rand(2000000) - 1000000) },

      name: proc { Faker::Name.name },
      email: proc { Faker::Internet.email },
      avatar: proc { Faker::Avatar.image },
      username: proc { Faker::Internet.username },
      hex_color: proc { Faker::Color.hex_color },
      color_name: proc { Faker::Color.color_name },
      domain: proc { Faker::Internet.domain_name },
      url: proc { Faker::Internet.url },
      markdown: proc { Faker::Markdown.sandwich }
    }.stringify_keys

    def self.default_types
      @default_types ||= TYPES_MAPPING.keys.each_with_object({}) do |name, r|
        r[name.to_s] = new('type' => name.to_s)
      end
    end

    def initialize(raw_data)
      @raw_data = raw_data
      @counter = 0
      @mutex = Mutex.new
    end

    def generate
      incr_counter
      if raw_data['type']
        TYPES_MAPPING[raw_data['type']].call(@counter)
      elsif raw_data['script']
        gen_by_script
      else
        gen_by_config
      end
    end

    private

    def incr_counter
      @mutex.synchronize { @counter += 1 }
    end

    def gen_by_script
      raise "TODO script feature"
    end

    def gen_by_config
      val = Array.wrap(raw_data['items'] || []).sample
      val = Array.wrap(raw_data['prefix']).sample.to_s + val.to_s if raw_data['prefix']
      val = val.to_s + Array.wrap(raw_data['suffix']).sample.to_s if raw_data['suffix']
      (val.is_a?(String) && val['%']) ? (val % { i: counter }) : val
    end
  end
end
