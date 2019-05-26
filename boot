#! /usr/bin/env ruby

$app_start_at = Time.now
$root = File.expand_path('..', __FILE__)
Dir.chdir($root)

$stdout.reopen('/dev/null') unless ENV['XJZ_STDOUT']
require 'xjz_loader'
XjzLoader.root = $root
XjzLoader.start
