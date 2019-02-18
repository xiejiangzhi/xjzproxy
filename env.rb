$app_env = ENV['APP_ENV'] || 'production'

require 'bundler/setup'
Bundler.require(:default, $app_env)

require 'active_support/core_ext'
require 'yaml'

$app_name = 'HappyDev'
$root = File.expand_path('../', __FILE__)

%w{
  cert_gen
  proxy_server
  request_proxy
  web_ui
}.each do |name|
  require File.join($root, 'src', name)
end

$config = YAML.load_file(File.join($root, 'config/config.yml'))
$cert_gen = CertGen.new

