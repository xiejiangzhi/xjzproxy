require 'bundler/setup'
Bundler.require(:default)

require './proxy_service'
require './show_service'

ps = ProxyService.new(8080)
pst = Thread.new do
  ps.proxy.start
end

ss = ShowService.new(8081, ps)
sst = Thread.new do
  ss.server.start
end

trap "INT"  do [ps.proxy, ss.server].each(&:shutdown) end
trap "TERM" do [ps.proxy, ss.server].each(&:shutdown) end

[pst, sst].each(&:join)

