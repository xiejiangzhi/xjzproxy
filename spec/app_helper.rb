ENV['APP_ENV'] = 'test'
ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

require 'webmock/rspec'
require 'fileutils'
require 'super_diff/rspec'

require 'bundler/setup'
Bundler.require(:default, 'test')

require 'spec_helper'

require File.expand_path('../../app', __FILE__)

Dir[File.expand_path('../support/*.rb', __FILE__)].each do |path|
  load path
end

Xjz::Logger.instance.instance_eval do
  old_logger = @logger
  @logger = Logger.new($stdout, level: :error)
  @logger.formatter = old_logger.formatter
end

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.include Support::TimeHelper
  config.include Support::NetworkHelper
  config.include Support::DataHelper

  config.after(:each) do
    (@sockets ||= []).each do |server, client, remote|
      remote.close rescue nil
      client.close rescue nil
      server.shutdown rescue nil
      server.close
    end

    FakeIO.clear
    Thread.list.each do |t|
      t.kill if t != Thread.current
    end
  end

  config.before(:each, server: true) do
    server = Xjz::Server.new
    server.start
    $config.shared_data.app.server = server
    $config.shared_data.app.webui = Xjz::WebUI.new(server)
  end
  config.after(:each, server: true) do
    $config.shared_data.app.server.stop
  end

  config.before(:each, log: false) do
    Xjz::Logger.instance.instance_eval do
      @logger.level = Logger::FATAL
    end
  end
  config.after(:each, log: false) do
    Xjz::Logger.instance.instance_eval do
      @logger.level = Logger::ERROR
    end
  end
end
