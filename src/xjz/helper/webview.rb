module Xjz
  class Helper::Webview
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

    def self.render(*args, &block)
      new.render(*args, &block)
    end

    def initialize
      @template_cache = {}
      @template_path_cache = {}
    end

    def render(name, vars = {}, helper_modules = nil, &block)
      ve = ViewEntity.new(vars, helper_modules, self)

      if Array === name
        layout, template = name.map { |p| fetch_template(fetch_template_path(p)) }
        render_template(layout, ve, vars) { render_template(template, ve, vars, &block) }
      else
        template = fetch_template(fetch_template_path(name))
        render_template(template, ve, vars, &block)
      end
    end

    private

    def render_template(template, *args, &block)
      template.render(*args, &block)
    rescue => e
      raise e if 'test' == $app_env
      Logger[:auto].error { e.log_inspect }
      "Failed to render template"
    end

    def fetch_template(path)
      @template_cache[path] ||= begin
        data_proc = nil
        # support $root/xxx and src/webviews/xxx
        if path.match?(/^\w/) || path[$root]
          data_proc = proc { XjzLoader.get_res(path.delete_prefix($root + '/')) }
        end
        Tilt.new(path, TEMPLATE_ARGS[Tilt[path]] || {}, &data_proc)
      end
    end

    def fetch_template_path(name)
      name = name.to_s
      return @template_path_cache[name] if @template_path_cache[name]
      template_dirs = [$config['template_dir'], 'src/webviews'].compact.map do |path|
        File.expand_path(path, $root)
      end
      path = @template_path_cache[name] = begin
        p = query_template_path(template_dirs, name)
        if p
          p
        else
          regexp = %r{^src/webviews/#{name}.(#{TEMPLATE_ENGINES.join('|')})$}
          XjzLoader.has_res?(regexp)
        end
      end
      return path if path
      raise("Not found template #{name}.(#{TEMPLATE_ENGINES.join('|')})")
    end

    def query_template_path(template_dirs, name)
      template_dirs.each do |template_dir|
        path = Dir[File.join(template_dir, "#{name}.{#{TEMPLATE_ENGINES.join(',')}}")].first
        return path if path && File.file?(path)
      end
      nil
    end

    class ViewEntity
      attr_reader :vars

      include ActiveSupport::NumberHelper

      def initialize(vars, helper_modules = nil, renderer = nil)
        @vars = (vars || {}).with_indifferent_access
        @helper_modules = helper_modules || []
        @helper_modules.each { |m| singleton_class.include(m) }
        @renderer = renderer
      end

      def render(name, new_vars = {}, &block)
        @renderer.render(
          name, vars.merge(new_vars.stringify_keys), @helper_modules, &block
        )
      end

      def t(*args); I18n.t(*args); end
      def l(*args); I18n.l(*args); end

      def number_to_human_interval(number)
        if number < 10
          "#{(number * 1000).to_i} ms"
        else
          "#{number.to_i} s"
        end
      end
    end
  end
end
