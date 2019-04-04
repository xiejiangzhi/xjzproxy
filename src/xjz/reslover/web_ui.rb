module Xjz
  class Resolver::WebUI
    attr_reader :req, :template_dir, :api_project

    def initialize(req, ap = nil)
      @api_project = ap
      @req = req
    end

    def perform
      body = Helper::Webview.render('index.html', history: Tracker.instance.history)
      HTTPHelper.write_res_to_conn(Response.new({}, [body], 200), req.user_socket)
    end
  end
end
