#! /usr/bin/env ruby

require './env'

$logger.info "Start #{$app_env}"

begin
  ProxyServer.new.start.join
rescue Interrupt
  puts "\nBye!"
end

