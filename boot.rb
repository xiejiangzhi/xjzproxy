#! /usr/bin/env ruby

$app_start_at ||= Time.now
$root = File.expand_path('..', __FILE__)
Dir.chdir($root)

if defined?(Xjz) && Xjz.respond_to?(:load_file)
  Xjz.load_file './app'
else
  require_relative './app'
end

ts = Time.now - $app_start_at
Xjz::Logger[:auto].debug { "Load time cost #{ts.round(3)}s" }
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
