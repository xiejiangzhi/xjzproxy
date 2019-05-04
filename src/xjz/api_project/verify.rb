require 'open3'
require 'google/protobuf'

module Xjz
  module ApiProject::Verifier
    extend self

    TYPE_SCHEMA = {
      items: [:optional, NilClass, Array],
      prefix: [:optional, NilClass, String, Array],
      suffix: [:optional, NilClass, String, Array],
      script: [:optional, NilClass, String]
    }.stringify_keys

    RESPONSE_SCHEMA = {
      http_code: Integer ,
      data: [Hash, String, Array]
    }.stringify_keys

    API_SCHEMA = {
      title: String,
      desc: [:optional, NilClass, String],
      method: String,
      path: String,
      labels: [:optional, NilClass, [[String]] ],
      query: [:optional, NilClass, Hash, String],
      body: [:optional, NilClass, Hash, String],
      body_type: [:optional, NilClass, String],
      headers: [:optional, NilClass, Hash],
      response: [String, Hash]
    }.stringify_keys

    PLUGIN_SCHEMA = {
      filter: {
        include_labels: [:optional, NilClass, [[String]] ],
        exclude_labels: [:optional, NilClass, [[String]] ],
        path: [:optional, NilClass, String],
        methods: [:optional, NilClass, [[String]] ],
      },
      query: [:optional, NilClass, String, Hash],
      body: [:optional, NilClass, String, Hash],
      body_type: [:optional, NilClass, String],
      headers: [:optional, NilClass, Hash],
      script: [:optional, NilClass, String]
    }.stringify_keys

    RAW_DATA_SCHEMA = {
      types: [:optional, NilClass, Hash],
      partials: [:optional, NilClass, Hash],
      responses: [:optional, NilClass, Hash],
      apis: [ [Hash] ],
      project: [:optional, [
        NilClass,
        {
          url: String,
          dir: String, # auto set when load
          grpc: [:optional, [
            NilClass,
            {
              dir: String,
              protoc_args: [:optional, NilClass, String],
              proto_files: [:optional, NilClass, [[String]] ]
            }
          ]]
        }
      ]],
      plugins: [:optional, NilClass, Hash]
    }.deep_stringify_keys

    REF_NAMES_MAPPING = {
      '.t' => 'types',
      '.p' => 'partials',
      '.r' => 'responses',
    }
    # .f/: read file
    REF_PREFIX = /^\.(t|p|r|f)\/.+/

    COMMENT_PREFIX = '.'
    EXPAND_HASH_FLAG = '.*'

    class ValidKey
      def initialize(key); @key = key.to_s; end
      def inspect; @key; end
    end

    def verify(raw_data, path = 'Hash')
      errors = valid_hash(raw_data, RAW_DATA_SCHEMA)
      [
        ['responses', RESPONSE_SCHEMA],
        ['plugins', PLUGIN_SCHEMA],
        ['types', TYPE_SCHEMA],
      ].each do |name, schema|
        next unless raw_data[name]
        raw_data[name].each do |key, val|
          errors.push(*valid_hash(val, schema, %Q{#{path}["#{name}"]["#{key}"]}))
        end
      end
      (raw_data['apis'] || []).each_with_index do |val, i|
        errors.push(*valid_hash(val, API_SCHEMA, %Q{#{path}["apis"][#{i}]}))
      end
      errors.empty? ? nil : errors
    end

    private

    def valid_hash(hash, schema, key = 'Hash')
      errors = []
      ClassyHash.validate(hash, schema,
        errors: errors,
        raise_errors: false,
        full: true,
        verbose: true,
        key: ValidKey.new(key)
      )
      errors
    end
  end
end
