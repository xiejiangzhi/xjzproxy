require 'uri'
require 'net/http'

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

    def emit_message(type, data)
      return false unless page_manager
      page_manager.emit_message("server.#{type}", data)
    end

    def render(name, vars = {})
      vars[:session] = page_manager.session
      Helper::Webview.render(name, vars, [WebUI::RenderHelper])
    end

    private

    def wait_server_ready
      res = Net::HTTP.get_response(URI.parse("http://#{ip}:#{port}/status"))
      res.code.to_i == 200
    rescue Net::OpenTimeout
      false
    rescue => e
      Logger[:auto].error { e.log_inspect }
      false
    end
  end
end
