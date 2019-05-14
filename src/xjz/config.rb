require 'fileutils'
require 'openssl'

module Xjz
  class Config
    attr_reader :path

    USER_DIR = ENV['XJZPROXY_USER_DIR'] || "#{Dir.home}/.xjzproxy"
    USER_PATH = File.join(USER_DIR, 'config.yml')
    LICENSE_PATH = File.join(USER_DIR, 'license.lcs')
    PUBLIC_KEY = File.read(ENV['XJZPROXY_PUBKEY_PATH'] || File.join($root, 'config/app.pub'))

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
      home_url: String,

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
        init_dir(pd) unless Dir.exist?(pd)
        pojs += Dir[File.join(pd, '*')].select { |dir| Dir.exist?(dir) }
      end
      pojs.uniq
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
        r.merge!(valid_license || {})
      end
    end

    def raw_data
      @raw_data ||= begin
        erb = ERB.new(File.read(path))
        erb.filename = path
        d = YAML.load(erb.result, filename: path)
        (d[$app_env] || d['default'] || d).merge(user_data)
      end
    end

    def user_data
      @user_data ||= begin
        if File.exist?(USER_PATH)
          YAML.load_file(USER_PATH) rescue {}
        else
          {}
        end
      end
    end

    def update_license(path)
      r = valid_license(path)
      return false unless r
      data.merge!(r)
      init_dir(USER_DIR)
      FileUtils.cp(path, LICENSE_PATH)
      true
    end

    def valid_license(path = LICENSE_PATH)
      return nil unless File.exist?(path)
      key = OpenSSL::PKey::RSA.new(PUBLIC_KEY)
      lcs = File.read(path)
      r = key.public_decrypt(lcs) rescue nil
      id, edition, ctime, etime, *_flags = r.to_s.split(',')
      et = etime.to_s.to_f > 0 ? Time.at(etime.to_f) : nil
      return nil unless id && (et.nil? || Time.now < et)
      {
        '.user_id' => id,
        '.edition' => edition,
        '.license_ts' => Time.at(ctime.to_s.to_f),
        '.license_ex' => et
      }
    end

    def changed_to_yaml
      data.reject { |k, v| k[0] == '.' || v == raw_data[k] }.to_yaml
    end

    def save
      if init_dir USER_DIR
        File.write(USER_PATH, changed_to_yaml)
      else
        Logger[:auto].error { "Failed to mkdir dir #{USER_DIR}" }
      end
    end

    private

    def init_dir(dir)
      unless Dir.exist?(dir)
        FileUtils.mkdir_p(dir)
      end
      true
    rescue Errno::ENOTSUP, Errno::EPERM
      false
    end

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
