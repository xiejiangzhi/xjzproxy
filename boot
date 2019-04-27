#! /usr/bin/env ruby

$app_start_at = Time.now
$root = File.expand_path('..', __FILE__)
Dir.chdir($root)

require './ext/loader/loader'
Xjz.start
