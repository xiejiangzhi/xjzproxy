ENV['APP_ENV'] = 'test'

require 'webmock/rspec'
require 'fileutils'
require 'super_diff/rspec'

require 'bundler/setup'
Bundler.require(:default, :development)

require 'spec_helper'

ENV['XJZPROXY_USER_DIR'] = File.expand_path('../files/app_home', __FILE__)
`rm -rf spec/files/app_home/config.yml`
# ENV['XJZPROXY_PUBKEY_PATH'] = 'xxx'

if ENV['PROD_CODE']
  $root = File.expand_path('../..', __FILE__)
  ENV['TOUCH_APP'] = '1'
  require 'xjz_loader'
  XjzLoader.root = $root
  XjzLoader.init
  XjzLoader.delete_code 'boot.rb'
  XjzLoader.load_file './app.rb'
else
  require File.expand_path('../../app.rb', __FILE__)
end

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
  config.include Support::WebpageHelper, webpage: true

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
    Xjz::Tracker.instance.clean_all
  end

  config.around(:each, log: false) do |example|
    Xjz::Logger.instance.instance_eval do
      @logger.level = Logger::FATAL
      example.run
      @logger.level = Logger::ERROR
    end
  end

  config.before :each, stub_config: true do
    data = $config.data.deep_dup
    allow($config).to receive(:data).and_return(data)
  end

  config.around(:each, allow_local_http: true) do |example|
    WebMock.disable_net_connect!(allow_localhost: true)
    example.run
    WebMock.disable_net_connect!
  end

  config.after(:each, stub_app_env: true) do
    $app_env = 'test'
  end
end
