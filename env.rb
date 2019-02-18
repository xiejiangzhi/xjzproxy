app_env = ENV['APP_ENV']
$app_env = case app_env
when 'staging', 'development', 'test', 'production' then app_env
when nil then 'production'
else
  puts "Invalid app env '#{app_env}'"
  'production'
end

require 'bundler/setup'
Bundler.require(:default, $app_env)

require 'active_support/core_ext'
require 'yaml'
require 'logger'

$app_name = 'HappyDev'
$root = File.expand_path('../', __FILE__)

Dir[File.join($root, 'src/**/*.rb')].each do |path|
  require path
end

$config = YAML.load_file(File.join($root, 'config/config.yml'))
$cert_gen = CertGen.new

$logger = Logger.new($stdout, level: ($app_env == 'production' ? :info : :debug))
