$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)
  require File.expand_path('../init', __FILE__)

  require 'xjz/logger'
  require 'xjz/config'
  config_path = ENV['CONFIG_PATH'] || File.join($root, 'config/config.yml')
  $config = Xjz::Config.new(config_path)

  # init sub module
  module Helper; end
  module Resolver; end
  class WebUI; end
  class ProxyClient; end

  Xjz::Logger[:auto].debug { "Loading code..." }
  require 'xjz/webui/action_router'
  Dir[File.join($root, 'src/xjz/**/*.rb')].sort.each { |path| require path }
end

Xjz::Logger[:auto].debug { "Verify config..." }
$config.verify.each do |err|
  Xjz::Logger[:auto].error { err }
end
Xjz::Logger[:auto].debug { "Load projects..." }
$config.load_projects
$config.shared_data.app.cert_manager = Xjz::CertManager.new
