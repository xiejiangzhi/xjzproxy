app_env = ENV['APP_ENV'] || ENV['RACK_ENV']
$app_env = case app_env
when 'stg', 'dev', 'test', 'prod' then app_env
when nil then 'prod'
else
  puts "Invalid app env '#{app_env}'"
  'prod'
end
ENV['RACK_ENV'] = $app_env

require 'bundler/setup'
Bundler.require(:default, $app_env)

require 'active_support/core_ext'
require 'yaml'

$root = File.expand_path('../', __FILE__)

config_path = ENV['CONFIG_PATH'] || File.join($root, 'config/config.yml')
$config = YAML.load_file(config_path)

$LOAD_PATH.unshift File.join($root, 'src')
