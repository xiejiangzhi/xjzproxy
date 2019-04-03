$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)

  require File.expand_path('../src/xjz/logger.rb', __FILE__)
  require File.expand_path('../src/xjz/config.rb', __FILE__)
  config_path = ENV['CONFIG_PATH'] || File.join($root, 'config/config.yml')
  $config = Xjz::Config.new(config_path)

  # init sub module
  module Helper; end
  module Resolver; end
  class ProxyClient; end

  Xjz::Logger[:auto].debug { "Loading code..." }
  Dir[File.join($root, 'src/xjz/**/*.rb')].sort.each { |path| require path }
end

Xjz::Logger[:auto].debug { "Verify config..." }
$config.verify.each do |err|
  Xjz::Logger[:auto].error { err }
end
Xjz::Logger[:auto].debug { "Load projects..." }
$config.load_projects
