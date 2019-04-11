module Xjz
  module Helper::Webview
    extend self

    TEMPLATE_ENGINES = %w{erb slim scss}
    TEMPLATE_ARGS = {
      Tilt['erb'] => {
        trim: '%-',
      },
      Tilt['slim'] => {
        disable_escape: true,
      },
      Tilt['scss'] => {
        style: :compressed
      }
    }

    def render(name, vars = {}, helper_modules = nil)
      ve = ViewEntity.new(vars, helper_modules)

      if Array === name
        layout, template = name.map { |p| fetch_template(fetch_template_path(p)) }
        layout.render(ve, vars) { template.render(ve, vars) }
      else
        template = fetch_template(fetch_template_path(name))
        template.render(ve, vars)
      end
    end

    private

    def fetch_template(path)
      Tilt.new(path, TEMPLATE_ARGS[Tilt[path]] || {})
    end

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
        dir, name = File.split(name)
        path = [dir, "_#{name}"].join(File::SEPARATOR)
        Helper::Webview.render(
          path, vars.merge(new_vars.stringify_keys), @helper_modules
        )
      end
    end
  end
end
