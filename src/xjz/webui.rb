module Xjz
  class WebUI
    attr_reader :server, :ip, :port, :window, :page_manager, :websocket

    def initialize(server)
      @server = server
      addr = server.ui_socket.local_address
      @ip, @port = addr.ip_address, addr.ip_port
      @window = WebUI::Browser.new
      @page_manager = WebUI::PageManager.new
      @running = false
      @websocket = nil
    end

    def start
      return true if @running
      if wait_server_ready
        window.open("http://#{ip}:#{port}")
        @running = true
        true
      else
        false
      end
    end

    def watch(websocket)
      @websocket = websocket
      page_manager.watch(websocket)
    end

    private

    def wait_server_ready
      Socket.tcp(ip, port, connect_timeout: 10).close
      true
    rescue Errno::ETIMEDOUT
      false
    rescue => e
      Logger[:auto].error { e.log_inspect }
      false
    end
  end
end
