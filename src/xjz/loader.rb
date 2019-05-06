module Xjz
  class << self
    unless self.respond_to?(:_load_file)
      def app_files
        @app_files ||= begin
          hash = Dir['*.rb', 'src/**/*.rb'].each_with_object({}) { |v, r| r[v] = true }
          hash.delete 'src/xjz/loader.rb'
          hash.delete 'boot.rb'
          hash.delete 'app.rb'
          hash
        end
      end

      def _load_file(path)
        if app_files[path]
          app_files.delete path
          load File.expand_path(path, $root)
        else
          puts "[Err] Not found file #{path}"
        end
      end
    end

    unless respond_to?(:load_all)
      def load_all
        app_files.keys.sort.each { |path, _| _load_file path }
        app_files.clear
      end
    end

    def load_file(path)
      if path =~ /^(xjz)\//
        path = "src/#{path}"
      elsif path.start_with?('./') && Dir.pwd == $root
        path.delete_prefix!('./')
      elsif path.start_with?($root)
        path.delete_prefix!($root + '/')
      else
        raise "Invalid load path #{path}"
      end

      path << '.rb' unless path.end_with?('.rb')
      _load_file(path)
    end
  end
end