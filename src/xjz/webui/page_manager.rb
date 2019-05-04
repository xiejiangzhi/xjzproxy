module Xjz
  class WebUI::PageManager
    attr_reader :websocket, :action_router, :session

    def initialize
      @websocket = nil
      @action_router = WebUI::ActionRouter.default
      @session = {}
    end

    def watch(websocket)
      @websocket = websocket
      websocket.bind(:message, &method(:on_message))
    end

    def on_message(frame)
      msg = JSON.parse(frame.data)
      emit_message(*msg.values_at('type', 'data'))
    end

    def emit_message(type, data)
      msg = Message.new(type, data, self)
      action_router.call(msg).tap do |r|
        Logger[:auto].warn { "Cannot handle message type #{type}" } unless r
      end
    end

    private

    class Message
      attr_reader :type, :data, :page_manager

      def initialize(type, data, page_manager)
        @type, @data = type, data.with_indifferent_access
        @page_manager = page_manager
      end
    end
  end
end
