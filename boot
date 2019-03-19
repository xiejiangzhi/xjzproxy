#! /usr/bin/env ruby

require './app'

Xjz::Logger[:app].info { "Environment #{$app_env}" }

ps = Xjz::ProxyServer.new

begin
  ps.start.join
rescue Interrupt
  ps.stop
  puts "\nBye!"
end
