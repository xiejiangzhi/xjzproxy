#! /usr/bin/env ruby

require './env'

$logger.info "Start #{$app_env}"

ps = ProxyServer.new

begin
  ps.start.join
rescue Interrupt
  ps.stop
  puts "\nBye!"
end

