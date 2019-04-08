module Xjz
  class WebUI::WebSocket
    attr_reader :conn, :ws_handshake, :ws_parser, :req

    BUFFER_SIZE = 4096

    EMPTY_PROC = proc { nil }

    EVENT_NAMES = Set.new(%w{open message close})

    def initialize(req)
      @req = req
      @conn = req.user_socket
      @ws_handshake = WebSocket::Handshake::Server.new
      @ws_parser = nil
      @out_buffer = ''

      @events = {}
    end

    def bing(name, &block)
      name = name.to_s
      raise "Invalid event name" unless EVENT_NAMES.include?(name)
      raise "Need a event block" unless block
      @events[name] = block
    end

    def emit(name, args = [])
      name = name.to_s
      raise "Invalid event name" unless EVENT_NAMES.include?(name)

      case name
      when 'open', 'close'
        Logger[:auto].info { "WebUI WebSocket event #{name}" }
      else
        Logger[:auto].debug do
          obj = args[0].respond_to?(:data) ? args[0].data : args
          "WebUI WebSocket event #{name} #{obj.inspect}"
        end
      end

      cb = @events[name]
      cb.call(*args) if cb
    end

    def perform
      if init_connect
        loop_data
        true
      else
        false
      end
    end

    def init_connect
      if accept_ws
        emit(:open)
        true
      else
        false
      end
    end

    private

    def loop_data
      readables = [conn]
      writeables = []
      loop do
        rs, ws = IO.select(readables, writeables)
        if rs.present?
          r = IOHelper.read_nonblock(conn) do |data|
            ws_parser << data
            read_frames
            writeables << conn unless @out_buffer.empty?
          end
          readables.clear unless r
        end

        if ws.present?
          IOHelper.write_nonblock(conn, @out_buffer)
          writeables.clear if @out_buffer.empty?
        end

        break if readables.empty? && writeables.empty?
      rescue => e
        Logger[:auto].error { e.log_inspect }
      end
    ensure
      emit(:close)
    end

    def read_frames
      loop do
        frame = ws_parser.next
        break unless frame
        emit(:message, [frame])
      end
    end

    # frame data:
    #   event: 'page_name.el_name.event_name'
    #   data: event_data
    def perform_frame(frame)
      data = JSON.parse(frame.data)
      data['event']
    rescue => e
      Logger[:auto].error { e.log_inspect }
    end

    def accept_ws
      ws_handshake << req.to_s
      if ws_handshake.finished? && ws_handshake.valid?
        Logger[:auto].debug { "Accepted WebUI WebSocket" }
        conn << ws_handshake.to_s
        @ws_parser = WebSocket::Frame::Incoming::Server.new(version: ws_handshake.version)
        true
      else
        Logger[:auto].debug { "Failed to accept WebUI WebSocket" }
        false
      end
    end
  end
end
