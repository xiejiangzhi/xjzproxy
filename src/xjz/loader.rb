module Xjz
  def self.LICENSE_CHECK(*flags)
    $config['.user_id'] = 'xiejiangzhi'
    $config['.edition'] = 'standard'
    $config['.license_ts'] ||= Time.now
    $config['.license_ex'] ||= Time.now + 1.day
    true
  end

  unless Xjz.respond_to?(:load_file)
    class << self
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

      def load_all
        app_files.keys.sort.each { |path, _| _load_file path }
        app_files.clear
      end

      def get_res(path)
        if File.exist?(path)
          File.read(path)
        else
          Logger[:auto].error { "Not found res #{path}" }
          nil
        end
      end

      def load_file(path)
        if path =~ /^(xjz)\//
          path = "src/#{path}"
        elsif path.start_with?('./') && Dir.pwd == $root
          path.delete_prefix!('./')
        elsif path.start_with?($root)
          path.delete_prefix!($root + '/')
        end

        path << '.rb' unless path.end_with?('.rb')
        _load_file(path)
      end
    end

    Object::MYRES = {}
  end
end
