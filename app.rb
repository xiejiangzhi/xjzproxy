$app_name = 'XJZProxy'
$root ||= File.expand_path('..', __FILE__)

require File.expand_path('src/xjz/loader', $root) unless defined?(Xjz) && Xjz.respond_to?(:load_file)

module Xjz
  load_file './env'

  load_file 'xjz/logger'
  load_file 'xjz/config'
  config_path = ENV['CONFIG_PATH'] || File.join($root, 'config/config.yml')
  $config = Xjz::Config.new(config_path)

  # init sub module
  module Helper; end
  module Resolver; end
  module PageActions; end
  module ProjectRender; end
  class WebUI; end
  class ProxyClient; end

  Xjz::Logger[:auto].debug { "Loading code..." }
  load_file 'xjz/webui/action_runner'
  load_file 'xjz/webui/action_router'
  load_all
end

Xjz::Logger[:auto].debug { "Verify config..." }
$config.verify.each do |err|
  Xjz::Logger[:auto].error { err }
end
Xjz::Logger[:auto].debug { "Load projects..." }
$config.load_projects
$config.shared_data.app.cert_manager = Xjz::CertManager.new
