require 'open3'
require 'google/protobuf'

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
      project: [:optional, [
        NilClass,
        {
          url: [:optional, NilClass, String],
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

    def parse(raw_data)
      %w{project types partials responses plugins apis}.each_with_object(
        'types' => ApiProject::DataType.default_types
      ) do |key, r|
        val = raw_data[key]
        r[key] ||= {}
        next unless val
        send("parse_#{key}", val, r)
      end
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
        m = api['method'].to_s.upcase
        url = Regexp.new('\A' + (api['url'] || purl) + '\Z')
        r[url] ||= {}
        expand_api = expand_hash(api, env)
        expand_api['.path_regexp'] = Regexp.new('\A' + expand_api['path'] + '(\.\w+)?\Z')
        expand_api['method'] = m
        (r[url][m] ||= []) << expand_api
      end
    end

    def parse_project(project, env)
      pj = env['project'] = project.deep_dup
      pj['.grpc_module'] = generate_and_load_grpc(project['grpc'], pj['dir'])
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
    #   .val.desc: desc
    #
    # key:
    #   .val.desc: desc
    #   val:
    #     s1: 123
    #     .s1.desc: xxx
    #     bb: xxx
    #
    # key:
    #   a: 1
    #   .*: .p/xxx # merge(.p/xxx)
    #   b: 2
    #
    def expand_hash(data, env)
      data.each_with_object({}) do |kv, r|
        k, v = kv
        if k == EXPAND_HASH_FLAG
          r.merge!(expand_var(v, env))
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

    def generate_and_load_grpc(conf, root_dir)
      return unless conf && conf['dir']
      dir = File.expand_path(conf['dir'], root_dir)
      unless File.directory?(dir)
        Logger[:auto].error { "Not found gRPC folder #{dir}" }
        return
      end

      out_dir = File.join(dir, '.xjzapi/protos')
      files = generate_protos(dir, out_dir, conf)
      load_protos(files, out_dir)
    end

    def generate_protos(dir, out_dir, conf)
      FileUtils.mkdir_p(out_dir)
      sout_dir = Shellwords.escape(out_dir)
      base_cmd = 'bundle exec grpc_tools_ruby_protoc'
      base_cmd += " --ruby_out=#{sout_dir} --grpc_out=#{sout_dir} -I#{Shellwords.escape(dir)}"
      files = []
      (conf['proto_files'] || ['**/*.proto']).each do |matcher|
        files.concat(Dir[File.join(dir, matcher)].to_a)
      end
      # TODO open3 to concurrent generate files
      files.uniq.map do |path|
        generate_pbfiles(base_cmd, path, sout_dir)
      end.compact.flatten
    end

    def generate_pbfiles(base_cmd, path, sout_dir)
      cmd = base_cmd + " #{Shellwords.escape(path)}"
      fname = File.basename(path).gsub(/\.[\w\-]+$/, '')
      out_files = [
        File.expand_path(fname + '_pb.rb', sout_dir),
        File.expand_path(fname + '_pb_service.rb', sout_dir)
      ]
      out_files_sts = out_files.each_with_object({}) do |f, r|
        r[f] = File.exist?(f) ? File.mtime(f) : nil
      end

      out, err, status = Open3.capture3(cmd)
      if status.exitstatus != 0
        Logger[:auto].error { "Error of #{cmd}: #{err.presence || out}" }
        return nil
      elsif err.present?
        Logger[:auto].warn { "#{path}: #{err.presence || out}" }
      end

      out_files.select do |fp|
        next false unless File.exist?(fp)
        mt = File.mtime(fp)
        mt && mt != out_files_sts[fp]
      end
    end

    def load_protos(files, out_dir)
      Google::Protobuf::DescriptorPool.class_eval do
        unless @xjz_gpdp
          @xjz_gpdp = true
          def self.generated_pool
            Thread.current[:google_protobuf_dp] ||= new
          end
        end
      end

      Module.new.tap do |m|
        m.module_exec do
          @loaded_paths = []

          define_singleton_method(:require) do |path|
            Kernel.require(path)
          rescue LoadError => e
            file = File.expand_path("#{path}.rb", out_dir)
            raise e unless File.exist?(file)
            load_code(file)
          end

          define_singleton_method(:load_code) do |path|
            return if @loaded_paths.include?(path)
            code = File.read(path)
            self.module_eval(code, path, 1)
            @loaded_paths << path
          end
        end

        Thread.current[:google_protobuf_dp] = nil
        files.each { |path| m.load_code(path) }
      end
    end
  end
end
