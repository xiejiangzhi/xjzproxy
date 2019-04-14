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

    def server
      $config.shared_data.app.server
    end

    def proxy_run?
      server.proxy_run?
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

    def max_reqs_in_sec(seconds)
      rts = Tracker.instance.history
      max = 0
      rt_times = rts.map { |rt| rt.start_at }
      rt_times.each_with_index do |st, i|
        rt_times[i..-1].each_with_index do |et, j|
          c = 1 + j
          max = c if (et - st) <= seconds && max < c
        end
      end
      max
    end
  end
end
