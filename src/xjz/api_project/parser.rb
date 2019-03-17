module Xjz
  module ApiProject::Parser
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
      project: [
        :optional,
        [
          NilClass,
          {
            url: [:optional, NilClass, String],
            dir: String # auto set when load
          }
        ]
      ],
      plugins: [:optional, NilClass, Hash]
    }.deep_stringify_keys

    REF_NAMES_MAPPING = {
      '.t' => 'types',
      '.p' => 'partials',
      '.r' => 'responses',
    }
    # .f/: read file
    REF_PREFIX = /^\.(t|p|r|f)\/.+/

    class ValidKey
      def initialize(key); @key = key.to_s; end
      def inspect; @key; end
    end

    def parse(raw_data)
      %w{project types partials responses plugins apis}.each_with_object(
        'types' => ApiProject::DataType.default_types
      ) do |key, r|
        val = raw_data[key]
        r[key] ||= {}
        send("parse_#{key}", val, r)
      end
    end

    def verify(raw_data)
      errors = valid_hash(raw_data, RAW_DATA_SCHEMA)
      [
        ['responses', RESPONSE_SCHEMA],
        ['plugins', PLUGIN_SCHEMA],
        ['types', TYPE_SCHEMA],
      ].each do |name, schema|
        raw_data[name].each do |key, val|
          errors.push(*valid_hash(val, schema, %Q{Hash["#{name}"]["#{key}"]}))
        end
      end
      raw_data['apis'].each_with_index do |val, i|
        errors.push(*valid_hash(val, API_SCHEMA, %Q{Hash["apis"][#{i}]}))
      end
      errors.empty? ? nil : errors
    end

    private

    def parse_types(types, env)
      r = env['types']
      types.each do |key, val|
        r[key] = ApiProject::DataType.new(val)
      end
    end

    def parse_partials(partials, env)
      r = env['partials']
      sort_by_dependents!(partials.to_a, '.p/').each do |key, val|
        r[key] = expand_hash(val, env)
      end
    end

    def parse_responses(responses, env)
      r = env['responses']
      responses.each do |key, val|
        r[key] = expand_hash(val, env)
      end
    end

    def parse_apis(apis, env)
      r = env['apis']
      purl = env['project']['url']
      apis.each do |api|
        key = [api['method'], (api['url'] || purl) + api['path']].join(' ')
        r[key] = expand_hash(api, env)
      end
    end

    def parse_project(project, env)
      env['project'] = project.deep_dup
    end

    def parse_plugins(plugins, env)
      r = env['plugins']
      plugins.each do |key, val|
        r[key] = expand_hash(val, env)
      end
    end

    #
    # key:
    #   val: 123 # const
    #
    # key:
    #   val: .t/integer # ref type
    #
    # key:
    #   val: .t/integer
    #   ./val.desc: desc
    #
    # key:
    #   ./val.desc: desc
    #   val:
    #     s1: 123
    #     ./s1.desc: xxx
    #     bb: xxx
    #
    def expand_hash(data, env)
      data.each_with_object({}) do |kv, r|
        k, v = kv
        if k =~ /^\.\w+/
          # .name.desc: ext data
          r[k] = v
        else
          r[k] = case v
          when Hash then expand_hash(v, env)
          when Array then expand_array(v, env)
          when REF_PREFIX then expand_var(v, env)
          else
            v
          end
        end
      end
    end

    def expand_array(data, env)
      data.map do |v|
        case v
        when Hash then expand_hash(v, env)
        when Array then expand_array(v, env)
        when REF_PREFIX then expand_var(v, env)
        else
          v
        end
      end
    end

    def expand_var(var, env)
      type, tmp = var.split('/', 2)
      name, oper, *args = tmp.split
      env_name = REF_NAMES_MAPPING[type]
      if env_name
        val = (env[env_name] || {})[name]
        raise "Not found variable '#{var}'" unless val
        return val if oper.nil?

        if oper == '*'
          [val] * args[0].to_i
        elsif env_name == 'types' && oper == 'args'
          ApiProject::DataType.new(val.raw_data.merge('args' => args))
        else
          raise "Invalid variable #{var}"
        end
      elsif type == '.f'
        path = File.join(env['project']['dir'], name)
        if File.exist?(path)
          File.read(path)
        else
          raise "Not found file #{path}"
        end
      end
    end

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

    def sort_by_dependents!(data, ref_prefix, keys = Set.new)
      return [] if data.empty?
      r = []
      data.delete_if do |kvds|
        k, v, _ = kvds
        kvds[2] ||= v.inspect.scan(/#{ref_prefix}([\w\-]+)/).flatten
        if kvds[2].all? { |d| keys.include?(d) }
          keys << k
          r << kvds
          true
        end
      end
      raise "Circular dependencies." if r.empty?
      r + sort_by_dependents!(data, ref_prefix, keys)
    end
  end
end
