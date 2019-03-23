$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)

  # init sub module
  module Reslover; end
  class ProxyClient; end

  Dir[File.join($root, 'src/xjz/**/*.rb')].sort.each { |path| load path }
end

config_path = ENV['CONFIG_PATH'] || File.join($root, 'config/config.yml')
$config = Xjz::Config.new(config_path)
$config.verify.each do |err|
  Xjz::Logger[:auto].error { err }
end
