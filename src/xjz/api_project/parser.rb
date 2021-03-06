
module Xjz
  module ApiProject::Parser
    extend self

    REF_NAMES_MAPPING = {
      '.t' => 'types',
      '.p' => 'partials',
      '.r' => 'responses',
    }
    # .f/: read file
    REF_PREFIX = /^\.(t|p|r|f)\/.+/
    OPTS_FIELD = /^(\.[\w-]+)+$/
    EXPAND_HASH_FLAG = '.*'

    class Error < StandardError; end

    def parse(raw_data)
      %w{project types partials responses plugins apis}.each_with_object(
        'types' => ApiProject::DataType.default_types.dup
      ) do |key, r|
        val = raw_data[key]
        r[key] ||= {}
        next unless val
        Logger[:auto].debug { "Parse #{key}" }
        send("parse_#{key}", val, r)
      end
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

    # Extend data:
    #   pj['.host_regexp']
    #   pj['.grpc_module']
    def parse_project(project, env)
      pj = env['project'] = project.deep_dup
      pj['.host_regexp'] = Regexp.new('\A' + pj['host'].to_s + '\Z')
      if grpc_options = pj['grpc']
        pj['.grpc_module'] = ApiProject::GRPCParser.new(pj['.dir'], grpc_options).parse
      end
    end

    def parse_plugins(plugins, env)
      r = (env['plugins'] = [])
      lip = (env['.label_indexed_plugins'] = {})

      plugins.each_with_index do |plugin, i|
        expand_plugin = expand_hash(plugin, env)
        expand_plugin['.index'] = i
        r << expand_plugin
        (expand_plugin['labels'] || []).each { |label| (lip[label] ||= []) << expand_plugin }
      end
    end

    # Extend data:
    #   api['method'].upcase
    #   api['.path_regexp']
    #   api['.index']
    def parse_apis(apis, env)
      env['apis'] = []
      Xjz.LICENSE_CHECK()
      apis.each_with_index do |api, i|
        m = api['method'].to_s.upcase
        expand_api = expand_hash(api_merge_plugins(api, env), env)
        expand_api['method'] = m
        expand_api['.path_regexp'] = Regexp.new('\A' + expand_api['path'] + '(\.\w+)?\Z')
        expand_api['.index'] = i
        env['apis'] << expand_api
      end
    end

    # key:
    #   val: 123 # const
    #
    # key:
    #   val: .t/integer # ref type
    #
    # key:
    #   val: .p/xxx
    #
    # key:
    #   .val.desc: desc
    #   .val:
    #     optional: true
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
        case k
        when EXPAND_HASH_FLAG then r.merge!(expand_var(v, env))
        when OPTS_FIELD
          ks = k[1..-1].split('.')
          field = ks.shift
          opts_field = ".#{field}"
          t = r[opts_field] ||= {}
          ks[0..-2].each { |k| t[k] ||= {}; t = t[k] }
          t[ks[-1]] = v
          r
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
        raise Error.new("Not found variable '#{var}'") unless val
        return val if oper.nil?

        if oper == '*'
          [val] * args[0].to_i
        elsif env_name == 'types' && oper == 'args'
          ApiProject::DataType.new(val.raw_data.merge('args' => args))
        else
          raise Error.new("Invalid variable #{var}")
        end
      elsif type == '.f'
        path = File.join(env['project']['.dir'], name)
        Logger[:auto].debug { "Parse .f, read #{path}" }
        if File.exist?(path)
          File.read(path)
        else
          raise Error.new("Not found file #{path}")
        end
      end
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
      raise Error.new("Circular dependencies.") if r.empty?
      r + sort_by_dependents!(data, ref_prefix, keys)
    end

    def api_merge_plugins(api, env)
      template = {}
      (api['labels'] || []).each do |label|
        plgs = (env['.label_indexed_plugins'] || {})[label]
        next unless plgs
        plgs.each do |plg|
          t = plg['template']
          template.deep_merge!(t) if t
        end
      end

      template.deep_merge!(api)
    end
  end
end
