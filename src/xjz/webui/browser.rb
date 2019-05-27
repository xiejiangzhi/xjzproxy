module Xjz
  class WebUI::Browser
    attr_reader :app

    def initialize
      @app = Webview::App.new(debug: $config['webview_debug'], title: $app_name)
    end

    def open(url); app.open(url); end
    def close; app.close; end
    def join; app.join; end
  end
end
