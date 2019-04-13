module Xjz
  module WebUI::RenderHelper
    def self.render(name, vars = {})
      Helper::Webview.render(name, vars, [self])
    end

    def history_group_each(&block)
      Xjz::Tracker.instance.history.group_by do |rt|
        req = rt.request
        [req.host, req.port].join(':')
      end.each do |host, rts|
        block.call(host, rts)
      end
    end

    def escape_html(str)
      Rack::Utils.escape_html(str)
    end

    def base64_encode(str)
      Base64.encode64(str)
    end

    def base64_url(str, type)
      "data:#{type};base64,#{base64_encode(str)}"
    end
  end
end
