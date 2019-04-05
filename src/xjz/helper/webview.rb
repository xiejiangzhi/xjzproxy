module Xjz
  module Helper::Webview
    extend self

    TEMPLATE_ENGINES = %w{erb slim}

    def render(name, vars = {}, helper_modules = nil)
      path = fetch_template_path(name)
      ve = ViewEntity.new(vars, helper_modules)

      case path
      when /\.slim$/i
        slim = Slim::Template.new(path, use_html_safe: true)
        slim.render(ve._slim_env)
      when /\.erb$/i
        erb = ERB.new(File.read(path), trim_mode: '%-')
        erb.filename = path
        erb.result(ve._erb_env)
      else
        raise "Not found template engine to render #{path}"
      end
    end

    private

    def fetch_template_path(name)
      template_dirs = [$config['template_dir'], 'src/webviews'].compact.map do |path|
        File.expand_path(path, $root)
      end
      template_dirs.each do |template_dir|
        path = Dir[File.join(template_dir, "#{name}.{#{TEMPLATE_ENGINES.join(',')}}")].first
        return path if path && File.file?(path)
      end
      raise "Not found template #{name}.(#{TEMPLATE_ENGINES.join('|')})"
    end

    class ViewEntity
      attr_reader :vars

      def initialize(vars, helper_modules = nil)
        @vars = (vars || {}).stringify_keys
        @helper_modules = helper_modules || []
        @helper_modules.each { |m| singleton_class.include(m) }
      end

      def render(name, new_vars = {})
        path = name.split('/')
        path[-1] = "_#{path[-1]}"
        path = path.join('/')
        Helper::Webview.render(
          path, vars.merge(new_vars.stringify_keys), @helper_modules
        ).html_safe
      end

      def _slim_env
        _setup_vars!
        self
      end

      def _erb_env
        _setup_vars!
        instance_eval { binding }
      end

      def _setup_vars!
        vars.each do |k, v|
          define_singleton_method(k) { v }
        end
      end
    end
  end
end
