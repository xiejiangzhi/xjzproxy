#! /usr/bin/env ruby

require './env'

$logger.info "Start #{$app_env}"
ProxyServer.new.start.join

