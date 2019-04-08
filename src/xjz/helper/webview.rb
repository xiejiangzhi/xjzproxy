module Xjz
  module Helper::Webview
    extend self

    TEMPLATE_ENGINES = %w{erb slim}
    TEMPLATE_ARGS = {
      trim: '%-',
      disable_escape: true,
    }

    def render(name, vars = {}, helper_modules = nil)
      ve = ViewEntity.new(vars, helper_modules)

      if Array === name
        layout, template = name.map { |p| Tilt.new(fetch_template_path(p), TEMPLATE_ARGS) }
        layout.render(ve, vars) { template.render(ve, vars) }
      else
        template = Tilt.new(fetch_template_path(name), TEMPLATE_ARGS)
        template.render(ve, vars)
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
        )
      end
    end
  end
end
