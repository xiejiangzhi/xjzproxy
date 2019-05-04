require 'fileutils'

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
      projects_dir: [:optional, NilClass, String],
      proxy_mode: String,
      host_whitelist: [:optional, NilClass, [[String]] ],
      template_dir: [:optional, NilClass, String],

      webview_debug: [:optional, NilClass, TrueClass],
      ui_window: [:optional, NilClass, TrueClass]
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

    def projects_paths
      pojs = data['projects'] || []
      if pd = data['projects_dir'].presence
        FileUtils.mkdir_p(pd) unless Dir.exist?(pd)
        pojs += Dir[File.join(pd, '*')].select { |dir| Dir.exist?(dir) }
      end
      pojs
    end

    def load_projects
      data['.api_projects'] = format_projects(projects_paths)
    end

    def shared_data
      @shared_data ||= build_obj(
        app: build_obj([:server, :webui, :cert_manager, :file_watcher], readonly: false),
        webui: build_obj([:ws], readonly: false)
      )
    end

    def [](key)
      data[key.to_s]
    end

    def []=(key, val)
      data[key.to_s] = val
    end

    def data
      @data ||= raw_data.slice(*SCHEMA.keys).deep_dup.tap do |r|
        r['projects'] ||= []
        r['host_whitelist'] ||= []
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

    # data: support each, first is key, last is value
    #   like hash, array
    def build_obj(data, readonly: true)
      Object.new.tap do |obj|
        keys = data.map { |k, _v| k }

        obj.singleton_class.class_eval do
          if readonly
            attr_reader(*keys)
          else
            attr_accessor(*keys)
          end
        end
        data.each do |k, v|
          next if v.nil?
          obj.instance_variable_set("@#{k}", v)
        end
      end
    end

    def format_projects(v)
      return [] unless v
      v.map do |p|
        ap = Xjz::ApiProject.new(p)
        if (errs = ap.errors).present?
          Xjz::Logger[:auto].error { "Failed to load project '#{p}'\n#{errs.join("\n")}" }
        end

        ap.data # try to parse
        ap
      rescue => e
        Xjz::Logger[:auto].error { e.log_inspect }
        nil
      end.compact
    end
  end
end
