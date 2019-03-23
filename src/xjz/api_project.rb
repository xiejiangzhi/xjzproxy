require 'erb'

module Xjz
  class ApiProject
    attr_reader :repo_path

    def initialize(repo_path)
      @repo_path = repo_path
    end

    def match_host?(host)
      _, t = data['apis'].find { |k, v| k.match?("https://#{host}") || k.match?("http://#{host}") }
      t ? true : false
    end

    # Return nil if don't hijack
    # Return a response if hijack req
    def hack_req(req)
      _, t = data['apis'].find { |k, v| k.match?("#{req.scheme}://#{req.host}") }
      return unless t
      apis = t[req.http_method.upcase] || []
      api = apis.find { |a| a['enabled'] != false && a['.path_regexp'].match?(req.path) }
      return unless api
      Logger[:auto].debug { "Match mock data: #{api['method']} #{api['path']}" }
      res = (api['response']['success'] || []).sample
      ApiProject::ResponseGenerator.generate(res)
    end

    def errors
      Parser.verify(raw_data, repo_path)
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
