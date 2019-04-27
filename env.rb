$root ||= File.expand_path('..', __FILE__)

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

require 'bundler'
gem_groups = [:default]
gem_groups << :development unless $app_env == 'prod'
Bundler.require(*gem_groups)

require 'yaml'
require 'active_support/core_ext'

I18n.load_path += Dir[File.join($root, 'config/locales/*.{yml,rb}')]
