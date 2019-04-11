#! /usr/bin/env ruby

require './app'

Xjz::Logger[:app].info { "Environment #{$app_env}" }

server = $config.shared_data.app.server = Xjz::Server.new
server.start_ui
server.start_proxy

paddr = server.proxy_socket.local_address
Xjz::Logger[:app].info { "Proxy Listen: #{[paddr.ip_address, paddr.ip_port].join(':')}" }
uiaddr = server.ui_socket.local_address
Xjz::Logger[:app].info { "UI Listen: #{[uiaddr.ip_address, uiaddr.ip_port].join(':')}" }

if ENV['OPEN_BROWSER'] != 'false'
  ui_ip, ui_port = uiaddr.ip_address, uiaddr.ip_port
  TCPSocket.new(ui_ip, ui_port).close # wait server ready
  window = Xjz::WebUI::Browser.new
  window.open("http://#{ui_ip}:#{ui_port}")
end

begin
  server.ui_thread.join
  server.stop_proxy
rescue Interrupt
  server.stop_proxy
  puts "\nBye!"
end
