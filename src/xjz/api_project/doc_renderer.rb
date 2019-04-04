module Xjz
  class ApiProject::DocRenderer
    attr_reader :api_project, :template_dir

    TEMPLATE_NAME = 'xjzapidoc.html'

    def initialize(ap)
      @api_project = ap
    end

    def render
      Helper::Webview.render(TEMPLATE_NAME, api_project.data)
    end
  end
end
