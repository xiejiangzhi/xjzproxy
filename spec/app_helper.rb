ENV['APP_ENV'] = 'test'
ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

require 'webmock/rspec'
require 'fileutils'

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
    end

    FakeIO.clear
  end
end
