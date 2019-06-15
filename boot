#! /usr/bin/env ruby

$app_start_at = Time.now
$root = File.expand_path('..', __FILE__)
Dir.chdir($root)

puts 'hello'
unless ENV['XJZ_STDOUT']
  $stdout.reopen(File::NULL)

  if File.exist?('XJZ_DEBUG.log')
    $logdev = File.open('XJZ_DEBUG.log', 'a+')
    $logdev.sync = true
  end
end

puts 'world'
require 'xjz_loader'
XjzLoader.root = $root
XjzLoader.start
