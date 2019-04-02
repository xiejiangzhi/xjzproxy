app_env = ENV['APP_ENV']
$app_env = case app_env
when 'stg', 'dev', 'test', 'prod' then app_env
when nil then 'prod'
else
  puts "Invalid app env '#{app_env}'"
  'prod'
end
ENV['RACK_ENV'] = $app_env

t = Time.now
require 'bundler/setup'
puts Time.now - t
Bundler.require(:default)

puts Time.now - t
require 'yaml'
require 'fileutils'
require 'active_support/core_ext'
require 'shellwords'

puts Time.now - t
$root = File.expand_path('../', __FILE__)

$LOAD_PATH.unshift File.join($root, 'src')
