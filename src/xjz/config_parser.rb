module Xjz
  module ConfigParser
    extend self

    TYPE_SCHEMA = {
      items: Array,
      prefix: Array,
      suffix: Array,
      script: String
    }

    RESPONSE_SCHEMA = {
      http_code: Integer ,
      data: [Hash, String, Array]
    }

    API_SCHEMA = {
      title: String,
      desc: String,
      method: String,
      path: String,
      labels: [ [String] ],
      query: [String, Hash, Array],
      body: [String, Hash, Array],
      body_type: String,
      response: [String, Hash]
    }

    PLUGIN_SCHEMA = {
      labels: [ [String] ]
    }

    RAW_DATA_SCHEMA = {
      types: Hash,
      partials: Hash,
      responses: {},
      apis: [ [API_SCHEMA] ],
      project: {
        scheme: String,
        host: String
      },
      plugins: Hash
    }

    class ValidKey
      def initialize(key); @key = key.to_s; end
      def inspect; @key; end
    end

    def parse(raw_config)
      raw_data.each_with_object({}) do |kv, r|
        key, val = kv
        r[key] = send("parse_#{key}", val)
      end
    end

    def verify(raw_config)
      errors = valid_hash(raw_data, RAW_DATA_SCHEMA)
      return errors unless errors.empty?
      errors = []
      [
        ['responses', RESPONSE_SCHEMA],
        ['plugins', PLUGIN_SCHEMA],
        ['types', TYPE_SCHEMA]
      ].each do |name, schema|
        raw_data[name].each do |key, val|
          errors.push(*valid_hash(val, schema, %Q{Hash["#{name}"]}))
        end
      end
      errors.empty? ? nil : errors
    end

    private

    def parse_types
    end

    def parse_partials
    end

    def parse_responses
    end

    def parse_apis
    end

    def parse_plugin
    end

    def expand_variables(data)
    end

    def valid_hash(hash, schema, key = 'Hash')
      errors = []
      ClassyHash.validate(hash, schema,
        errors: errors,
        raise_errors: false,
        full: true,
        strict: true,
        verbose: true,
        key: ValidKey.new(key)
      )
      errors
    end
  end
end
