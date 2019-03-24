module Xjz
  class Config
    attr_reader :path

    SCHEMA = {
      root_ca_path: String,
      key_path: String,
      proxy_timeout: Integer,
      proxy_port: Integer,
      alpn_protocols: [[String]],
      max_threads: Integer,
      logger_level: Hash,
      projects: [:optional, NilClass, [[String]] ],
      proxy_mode: String,
      host_whitelist: [:optional, NilClass, [[String]] ],
      host_blacklist: [:optional, NilClass, [[String]] ]
    }.stringify_keys

    def initialize(path)
      @path = path
    end

    def verify
      errors = []
      ClassyHash.validate(raw_data, SCHEMA,
        errors: errors,
        raise_errors: false,
        full: true,
        verbose: true,
        key: Config
      )
      errors
    end

    def load_projects
      data['.api_projects'] = format_projects(data['projects'])
    end

    def [](key)
      data[key.to_s]
    end

    def []=(key, val)
      data[key.to_s] = val
    end

    def data
      @data ||= raw_data.slice(*SCHEMA.keys).deep_dup.tap do |r|
        r['host_whitelist'] ||= []
        r['host_blacklist'] ||= []
        r['logger_level'] ||= {}
        r['alpn_protocols'] ||= %w{h2 http/1.1}
      end
    end

    def raw_data
      @raw_data ||= begin
        erb = ERB.new(File.read(path))
        erb.filename = path
        d = YAML.load(erb.result, filename: path)
        d[$app_env] || d['default'] || d
      end
    end

    def to_yaml
      data.reject { |k, v| k[0] == '.' }.to_yaml
    end

    private

    def format_projects(v)
      return [] unless v
      v.map do |p|
        ap = Xjz::ApiProject.new(p)
        if errs = ap.errors
          Xjz::Logger[:auto].error { "Failed to load project '#{p}'\n#{errs.join("\n")}" }
          nil
        else
          ap.data # try to parse
          ap
        end
      rescue => e
        Xjz::Logger[:auto].error { e.log_inspect }
        nil
      end.compact
    end
  end
end
