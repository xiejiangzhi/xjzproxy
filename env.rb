$root = File.expand_path('../', __FILE__)

app_env = ENV['APP_ENV']
$app_env = case app_env
when 'stg', 'dev', 'test', 'prod' then app_env
when nil then 'prod'
else
  puts "Invalid app env '#{app_env}'"
  'prod'
end
ENV['RACK_ENV'] = $app_env
ENV['BOOTSNAP_CACHE_DIR'] = File.expand_path('tmp/bootsnap', $root)

t = Time.now
require 'bundler/setup'
require 'bootsnap/setup' if $LOAD_PATH.include?('bootsnap')
puts Time.now - t
Bundler.require(:default)

puts Time.now - t
require 'yaml'
require 'fileutils'
require 'active_support/core_ext'
require 'shellwords'

puts Time.now - t

I18n.load_path += Dir[File.join($root, 'config/locales/*.{yml,rb}')]

$LOAD_PATH.unshift File.join($root, 'src')
$LOAD_PATH.unshift File.join($root, 'lib')
