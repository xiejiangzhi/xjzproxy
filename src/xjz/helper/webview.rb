module Xjz
  module Helper::Webview
    extend self

    TEMPLATE_ARGS = {
      use_html_safe: true
    }

    def render(name, vars = {})
      path = fetch_template_path(name)
      Slim::Template.new(path, TEMPLATE_ARGS).render(ViewEntity.new(vars))
    end

    private

    def fetch_template_path(name)
      template_dirs = [$config['template_dir'], 'src/webviews'].compact.map do |path|
        File.expand_path(path, $root)
      end
      template_dirs.each do |template_dir|
        path = File.join(template_dir, "#{name}.slim")
        return path if File.exist?(path)
      end
      raise "Not found template #{name}.slim"
    end

    class ViewEntity
      attr_reader :vars

      def initialize(vars)
        @vars = vars || {}
      end

      def render(name, vars = {})
        Helper::Webview.render("_#{name}", vars).html_safe
      end

      def css_tag(src, attrs = {})
      end

      def js_tag(src, attrs = {})
      end
    end
  end
end
