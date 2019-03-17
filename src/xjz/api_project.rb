module Xjz
  class ApiProject
    attr_reader :repo_path

    def initialize(repo_path)
      @repo_path = repo_path
    end

    # Return nil if don't hijack
    # Return a response if hijack req
    def inspect_req(req)
    end

    def errors
      Parser.verify(raw_data)
    end

    def data
      @data ||= Parser.parse(raw_data)
    end

    def raw_data
      @raw_data ||= begin
        if File.directory?(repo_path)
          load_dir(repo_path)
        else
          load_file(repo_path)
        end
      end
    end

    private

    def load_dir(dir_path)
      Dir["#{dir_path}/**/*.{yml,yaml}"].each_with_object({}) do |path, r|
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
      YAML.load_file(file_path)
    end
  end
end
