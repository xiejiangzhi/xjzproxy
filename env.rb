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

$rfts = {}
DEBUG_KEY = 'XJZ_LOAD_DEBUG'

if ENV[DEBUG_KEY]
  def require(*args)
    sts = Time.now
    Kernel.require(*args)
  ensure
    fname = args.first
    fname = fname.split('/gems/').last if fname.match?(/^(c:|\/u)/i)
    pkg_name = fname.split('/').first
    ets = Time.now
    ($rfts[pkg_name] ||= []) << [sts, ets, fname]
  end

  def show_rfts
    $rfts.map do |k, rts|
      ms = (rts.map { |s, e, _| e - s }.reduce(&:+) * 1000).round(3)
      [k, rts, ms]
    end.sort_by(&:last).each do |k, rts, ms|
      puts "require #{k} - #{rts.size} files, cost #{ms}ms"
      # rts.each do |sts, ets, fname|
      #   puts " - #{fname} cost #{((ets - sts) * 1000).round(3)}ms"
      # end
    end
    arr_rfts = $rfts.values
    ms = ((arr_rfts[-1][-1][1] - arr_rfts[0][0][0]) * 1000).round(3)
    puts "total cost #{ms}ms"
  end
end

puts "1 ts: #{Time.now - $app_start_at}" if ENV[DEBUG_KEY]

require 'bundler'
gem_groups = [:default]
gem_groups << :development unless $app_env == 'prod'

Bundler.setup(*gem_groups)

puts "2 ts: #{Time.now - $app_start_at}" if ENV[DEBUG_KEY]

require 'webview'

if Gem.win_platform? && $app_env != 'test'
  $loading_window = Webview::App.new(
    width: 600, height: 400, title: "#{$app_name} Loading"
  )
  $loading_window.open('file://' + File.join($root, 'loading.html'))
end

Bundler.require(*gem_groups)
puts "3 ts: #{Time.now - $app_start_at}" if ENV[DEBUG_KEY]

require 'faker'

require 'yaml'
require 'objspace'
require 'active_support/dependencies/autoload'
require 'active_support/number_helper'
%w{
  hash/deep_merge hash/slice hash/indifferent_access hash/conversions
  array/wrap array/conversions
  string/output_safety string/strip
  integer/time numeric/time
  numeric/bytes
  object/deep_dup module/introspection
}.each do |f|
  require "active_support/core_ext/#{f}"
end

puts "4 ts: #{Time.now - $app_start_at}" if ENV[DEBUG_KEY]
show_rfts if ENV[DEBUG_KEY]
exit if ENV[DEBUG_KEY]

I18n.load_path += Dir[File.join($root, 'config/locales/*.{yml,rb}')]
