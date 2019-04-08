#! /usr/bin/env ruby

require './app'

Xjz::Logger[:app].info { "Environment #{$app_env}" }

ps = Xjz::ProxyServer.new

paddr = ps.server_socket.local_address
Xjz::Logger[:app].info { "Proxy Listen: #{[paddr.ip_address, paddr.ip_port].join(':')}" }

begin
  ps.start.join
rescue Interrupt
  ps.stop
  puts "\nBye!"
end
