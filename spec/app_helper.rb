ENV['APP_ENV'] = 'test'
ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

require 'webmock/rspec'
require 'fileutils'
require 'super_diff/rspec'

require 'bundler/setup'
Bundler.require(:default, 'test')

require 'spec_helper'

$root = File.expand_path('../../', __FILE__)
require File.expand_path('./loader', $root)
Xjz.load_file './app'

Dir[File.expand_path('../support/*.rb', __FILE__)].each do |path|
  load path
end

Xjz::Logger.instance.instance_eval do
  old_logger = @logger
  @logger = Logger.new($stdout, level: :error)
  @logger.formatter = old_logger.formatter
end

WebMock.disable_net_connect!

$server = Xjz::Server.new
$server.start
$webui = Xjz::WebUI.new($server)

$config.shared_data.app.server = $server
$config.shared_data.app.webui = $webui

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
    # clear old threads
    Thread.list.each do |t|
      next if t == Thread.current
      next if t == $server.proxy_thread
      next if t == $server.ui_thread
      t.kill
    end
    $webui.page_manager.session.clear
  end

  config.around(:each, log: false) do |example|
    Xjz::Logger.instance.instance_eval do
      @logger.level = Logger::FATAL
      example.run
      @logger.level = Logger::ERROR
    end
  end

  config.around(:each, allow_local_http: true) do |example|
    WebMock.disable_net_connect!(allow_localhost: true)
    example.run
    WebMock.disable_net_connect!
  end
end
