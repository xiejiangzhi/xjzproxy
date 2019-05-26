$app_name = 'XJZProxy'

# for testing, load this file without $root
$root ||= File.expand_path('..', __FILE__)

unless defined?(XjzLoader) && XjzLoader.respond_to?(:load_file)
  require File.expand_path('../src/xjz/loader', __FILE__)
end

module Xjz
  XjzLoader.load_file './env'

  XjzLoader.load_file 'xjz/logger'
  XjzLoader.load_file 'xjz/config'
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
  XjzLoader.load_file 'xjz/webui/action_runner'
  XjzLoader.load_file 'xjz/webui/action_router'
  XjzLoader.load_all
end

Xjz::Logger[:auto].debug { "Verify config..." }
$config.verify.each do |err|
  Xjz::Logger[:auto].error { err }
end
Xjz::Logger[:auto].debug { "Load projects..." }
$config.load_projects
$config.shared_data.app.cert_manager = Xjz::CertManager.new
