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

def require(*args)
  sts = Time.now
  Kernel.require(*args)
ensure
  fname = args.first
  fname = fname.split('/gems/').last if fname.match?(/^c:/i)
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
    rts.each do |sts, ets, fname|
      puts " - #{fname} cost #{((ets - sts) * 1000).round(3)}ms"
    end
  end
  arr_rfts = $rfts.values
  ms = ((arr_rfts[-1][-1][1] - arr_rfts[0][0][0]) * 1000).round(3)
  puts "total cost #{ms}ms"
end

# Kernel.require('bundler')

puts method(:require).inspect

%w{
  uri pathname thread fileutils delegate rbconfig shellwords digest
  forwardable tempfile cgi stringio json timeout base64 time date
  erb ostruct tmpdir rubygems singleton net/http socket
}.map do |name|
  Thread.new { require name }
end.map(&:join)

show_rfts
$rfts = {}

puts "0 ts: #{Time.now - $app_start_at}"

puts "1 ts: #{Time.now - $app_start_at}"
require 'bundler'
gem_groups = [:default]
gem_groups << :development unless $app_env == 'prod'
puts "2 ts: #{Time.now - $app_start_at}"
Bundler.require(*gem_groups)
puts "3 ts: #{Time.now - $app_start_at}"

require 'yaml'
require 'objspace'
require 'active_support/core_ext'
puts "4 ts: #{Time.now - $app_start_at}"

show_rfts
exit

I18n.load_path += Dir[File.join($root, 'config/locales/*.{yml,rb}')]
