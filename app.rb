# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default)

# EvilProxy::HTTPProxyServer is a subclass of Webrick::HTTPProxyServer;
#   it takes the same parameters.
proxy = EvilProxy::MITMProxyServer.new Port: 8080

proxy.before_request do |req|
  # Do evil things
  # Note that, different from Webrick::HTTPProxyServer,
  #   `req.body` is writable.
end

proxy.before_response do |req, res|
  # Here `res.body` is also writable.
  puts '=' * 50
end

trap "INT"  do proxy.shutdown end
trap "TERM" do proxy.shutdown end

proxy.start
