module Xjz
  class WebUI::Browser
    attr_reader :app

    def initialize
      title = "#{$app_name} - #{$app_version}"
      @app = Webview::App.new(debug: $config['webview_debug'], title: title)
    end

    def open(url); app.open(url); end
    def close; app.close; end
    def join; app.join; end
  end
end
