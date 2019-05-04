module Xjz
  class WebUI::ActionRunner
    attr_reader :msg
    attr_accessor :match_data

    class << self
      attr_accessor :last_runner
    end

    def initialize(msg, match_data = nil)
      @msg = msg
      @match_data = match_data
    end

    def render(*args)
      WebUI::RenderHelper.render(*args)
    end

    def send_msg(type, data = nil)
      msg.page_manager.websocket&.send_msg(type, data)
    end

    def type; msg.type; end
    def data; msg.data; end
    def session; msg.page_manager.session; end
  end
end
