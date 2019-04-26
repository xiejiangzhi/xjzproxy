#! /usr/bin/env ruby

require_relative './app'

Xjz::Logger[:app].info { "Environment #{$app_env}" }

server = $config.shared_data.app.server = Xjz::Server.new
server.start

webui = $config.shared_data.app.webui = Xjz::WebUI.new(server)

main_thread = if $config['ui_window'] != false
  webui.start
  webui.window
else
  server.proxy_thread
end

begin
  main_thread.join
  server.stop
rescue Interrupt
  server.stop
  puts "\nBye!"
end
