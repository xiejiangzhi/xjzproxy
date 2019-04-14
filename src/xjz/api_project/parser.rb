
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

    COMMENT_PREFIX = '.'
    EXPAND_HASH_FLAG = '.*'

    def parse(raw_data)
      %w{project types partials responses plugins apis}.each_with_object(
        'types' => ApiProject::DataType.default_types.dup
      ) do |key, r|
        val = raw_data[key]
        r[key] ||= {}
        next unless val
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

    def parse_apis(apis, env)
      r = env['apis']
      purl = env['project']['url']
      apis.each_with_index do |api, i|
        m = api['method'].to_s.upcase
        url = (api['url'] ||= purl)
        url_regexp = Regexp.new('\A' + url + '\Z')
        r[url_regexp] ||= {}
        expand_api = expand_hash(api, env)
        expand_api['.path_regexp'] = Regexp.new('\A' + expand_api['path'] + '(\.\w+)?\Z')
        expand_api['method'] = m
        expand_api['.index'] = i
        (r[url_regexp][m] ||= []) << expand_api
      end
    end

    def parse_project(project, env)
      pj = env['project'] = project.deep_dup
      if grpc_options = pj['grpc']
        pj['.grpc_module'] = ApiProject::GRPCParser.new(pj['dir'], grpc_options).parse
      end
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
