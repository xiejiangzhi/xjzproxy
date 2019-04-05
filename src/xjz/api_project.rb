require 'erb'

module Xjz
  class ApiProject
    attr_reader :repo_path, :response_renderer

    def initialize(repo_path)
      @repo_path = repo_path
      @response_renderer = ApiProject::ResponseRenderer.new(self)
    end

    def match_host?(host)
      _, t = data['apis'].find { |k, v| k.match?("https://#{host}") || k.match?("http://#{host}") }
      t ? true : false
    end

    # Return nil if don't hijack
    # Return a response if hijack req
    def hack_req(req)
      res = if grpc
        grpc.res_desc(req.path)
      else
        api = find_api(req.http_method, req.scheme, req.host, req.path)
        if api.nil? || api['.enabled'] == false || api['enabled'] == false
          nil
        else
          (api&.dig('response', 'success') || []).sample
        end
      end
      return unless res
      Logger[:auto].debug { "Match mock data: #{req.http_method} #{req.path}" }
      @response_renderer.render(req, res)
    end

    def find_api(http_method, scheme, host, path)
      h_apis = if scheme.nil? && host.nil?
        data['apis'].values
      else
        data['apis'].select { |k, v| k.match?("#{scheme}://#{host}") }.map(&:last)
      end
      return if h_apis.empty?
      h_apis.each do |t|
        apis = t[http_method.upcase]
        next unless apis
        api = apis.find { |a| a['.path_regexp'].match?(path) }
        return api if api
      end
      nil
    end

    def errors
      Verifier.verify(raw_data, repo_path)
    end

    def grpc
      return unless data['project']['.grpc_module']
      @grpc ||= ApiProject::GRPC.new(self)
    end

    def data
      @data ||= Parser.parse(raw_data)
    end

    def raw_data
      @raw_data ||= begin
        if File.directory?(repo_path)
          load_dir(repo_path).tap { |d| (d['project'] || {})['dir'] ||= repo_path }
        else
          load_file(repo_path).tap { |d| (d['project'] || {})['dir'] ||= File.dirname(repo_path) }
        end
      end
    end

    private

    def load_dir(dir_path)
      Dir["#{dir_path}/**/*.{yml,yaml}"].sort.each_with_object({}) do |path, r|
        load_file(path).each do |key, val|
          next unless val
          if val.is_a?(Array)
            (r[key] ||= []).push(*val)
          else
            (r[key] ||= {}).merge!(val)
          end
        end
      end
    end

    def load_file(file_path)
      erb = ERB.new(File.read(file_path))
      erb.filename = file_path
      YAML.load(erb.result, filename: file_path)
    end
  end
end
