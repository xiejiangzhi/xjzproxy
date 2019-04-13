module Xjz
  class WebUI::PageManager
    attr_reader :websocket, :action_router

    def initialize
      @websocket = nil
      @action_router = WebUI::ActionRouter.default
    end

    def watch(websocket)
      @websocket = websocket
      websocket.bind(:message, &method(:on_message))
    end

    def on_message(frame)
      msg = JSON.parse(frame.data)
      type, data = msg['type'], msg['data']

      msg = Message.new(type, data, self)
      action_router.call(msg).tap do |r|
        Logger[:auto].warn { "Cannot handle message type #{type}" } unless r
      end
    end

    private

    class Message
      attr_reader :type, :data, :page_manager
      attr_accessor :match_data

      def initialize(type, data, page_manager)
        @type, @data = type, data
        @page_manager = page_manager
      end

      def send_msg(type, data = nil)
        page_manager.websocket.send_msg(type, data)
      end

      def render(*args)
        WebUI::RenderHelper.render(*args)
      end
    end
  end
end
