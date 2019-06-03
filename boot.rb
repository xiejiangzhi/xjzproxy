#! /usr/bin/env ruby

$app_start_at ||= Time.now
$root = File.expand_path('..', __FILE__)
Dir.chdir($root)

if defined?(XjzLoader) && XjzLoader.respond_to?(:load_file)
  XjzLoader.load_file './app'
else
  require_relative './app'
end

ts = Time.now - $app_start_at
Xjz::Logger[:auto].debug { "Load time cost #{ts.round(3)}s" }
Xjz::Logger[:app].info { "Environment #{$app_env}" }

# Xjz#.LICENSE_CHECK()
Xjz::Logger[:auto].info do
  "license id: #{$config['.user_id']}, flags #{$config['.license']}"
end

Process.setproctitle($app_name)

server = $config.shared_data.app.server = Xjz::Server.new
server.start

webui = $config.shared_data.app.webui = Xjz::WebUI.new(server)

fw = $config.shared_data.app.file_watcher = Xjz::FileWatcher.new
fw.start

main_thread = if $config['ui_window'] != false
  webui.start
  webui.window
else
  server.proxy_thread
end

at_exit do
  webui.window.close
  server.stop
end

begin
  main_thread.join
rescue Interrupt
  puts "\nBye!"
end
