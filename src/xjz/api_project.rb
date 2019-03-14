module Xjz
  class ApiProject
    attr_reader :repo_path

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

    def initialize(repo_path)
      @repo_path = repo_path
    end

    def inspect_req(req)
    end

    # Return nil if don't hijack
    # Return a response if hijack req
    def inspect_req(req)
    end

    def raw_data
      @raw_data ||= begin
        if File.directory?(repo_path)
          load_dir(repo_path)
        else
          load_file(repo_path)
        end
      end
    end

    def valid?
      errors = valid_hash(raw_data, RAW_DATA_SCHEMA)
      return errors unless errors.empty?
      errors = []
      [
        ['responses', RESPONSE_SCHEMA],
        ['plugins', PLUGIN_SCHEMA],
        ['types', TYPE_SCHEMA]
      ].each do |name, schema|
        raw_data[name].each do |key, val|
          errors.push(*valid_hash(val, schema, "Hash[\"#{name}\"]"))
        end
      end
      return errors unless errors.empty?
    end

    private

    def load_dir(dir_path)
    end

    def load_file(file_path)
      YAML.load_file(file_path)
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

    class ValidKey
      def initialize(key); @key = key.to_s; end
      def inspect; @key; end
    end
  end
end
