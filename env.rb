$app_env = ENV['APP_ENV'] || 'production'

require 'bundler/setup'
Bundler.require(:default, $app_env)

require 'active_support/core_ext'

$app_name = 'HappyDev'
$root = File.expand_path('../', __FILE__)

