#! /usr/bin/env ruby

require './app'

Xjz::Logger[:app].info { "Environment #{$app_env}" }

server = $config.shared_data.app.server = Xjz::Server.new
server.start

webui = $config.shared_data.app.webui = Xjz::WebUI.new(server)
webui.start if ENV['OPEN_BROWSER'] != 'false'

begin
  server.ui_thread.join
  server.stop
rescue Interrupt
  server.stop
  puts "\nBye!"
end
