module Xjz
  class ApiProject
    attr_reader :repo_path, :response_renderer, :cache

    def initialize(repo_path)
      @repo_path = repo_path
      @response_renderer = ApiProject::ResponseRenderer.new(self)

      @grpc = nil
      @data = nil
      @errors = nil
      @raw_data = nil
      @last_reload_at = Time.now
      @cache = {}
    end

    def match_host?(host)
      return false if data['.enabled'] == false
      r = data['project']['.host_regexp']
      return true if r && r.match?(host)
      false
    end

    # Return nil if don't hijack
    # Return a response if hijack req
    def hack_req(req)
      return if data['.enabled'] == false
      res = if grpc
        grpc.res_desc(req.path)
      else
        api = find_api(req.http_method, req.path)
        return unless api
        if api['.enabled'] == false || api['enabled'] == false
          nil
        else
          r = api['response']
          return unless r
          r[r['.default'] || 'success']
        end
      end
      return unless res
      Logger[:auto].debug { "Match mock data: #{req.http_method} #{req.path}" }
      @response_renderer.render(req, res)
    end

    def find_api(http_method, path)
      data['apis'].each do |api|
        next unless api['method'] == http_method.to_s.upcase
        next unless api['.path_regexp'].match?(path)
        return api
      end
      nil
    end

    def errors
      @errors ||= Verifier.verify(raw_data, repo_path) || []
    end

    def grpc
      return unless data['project']['.grpc_module']
      return unless Xjz.APP_EDITION
      @grpc ||= ApiProject::GRPC.new(self)
    end

    def data
      @data ||= Parser.parse(raw_data)
    end

    def raw_data
      @raw_data ||= begin
        if File.directory?(repo_path)
          load_dir(repo_path).tap { |d| (d['project'] || {})['.dir'] ||= repo_path }
        else
          load_file(repo_path).tap { |d| (d['project'] || {})['.dir'] ||= File.dirname(repo_path) }
        end
      end
    end

    def reload(force: false, interval: 5)
      if @last_reload_at.nil? || (Time.now - @last_reload_at) >= interval
        @grpc = nil
        @data = nil
        @errors = nil
        @raw_data = nil
        @cache.clear
        data
        Logger[:auto].info { "Reload project #{repo_path}" }
        @last_reload_at = Time.now
        true
      else
        false
      end
    end

    def files(dir_path = repo_path)
      Dir["#{dir_path}/**/*.{yml,yaml}"]
    end

    def repo_dir
      data['project']['.dir']
    end

    private

    def load_dir(dir_path)
      files.sort.each_with_object({}) do |path, r|
        load_file(path).each do |key, val|
          next unless val
          if val.is_a?(Array)
            (r[key] ||= []).push(*val)
          elsif val.is_a?(Hash)
            (r[key] ||= {}).merge!(val)
          else
            Logger[:auto].error { "Invalid config file #{path}" }
          end
        end
      end
    end

    def load_file(file_path)
      erb = ERB.new(File.read(file_path))
      erb.filename = file_path
      fdata = YAML.load(erb.result, filename: file_path)
      fdata.is_a?(Hash) ? fdata : {}
    end
  end
end
