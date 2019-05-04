module Support
  module WebpageHelper
    def expect_runner
      expect_any_instance_of(runner_cls)
    end

    def expect_runner_render(*args)
      expect_runner.to g_call_ep(:render, *args)
    end

    def expect_runner_send_msg(*args)
      expect_runner.to g_call_ep(:send_msg, *args)
    end

    def emit_msg(*args)
      msg = new_webmsg(*args)
      web_router.call(msg)
    end

    def runner_cls
      Xjz::WebUI::ActionRouter.default.classes[self.class.top_level_description]
    end

    def runner
      runner_cls.last_runner
    end

    def session
      $config.shared_data.app.webui.page_manager.session
    end

    private

    def g_call_ep(mname, args = nil, result = nil)
      ep = receive(mname)
      ep = ep.with(*args) if args
      ep = case result
      when :original
        ep.and_call_original
      when nil
        ep
      else
        ep.and_return(result)
      end
    end
  end
end
