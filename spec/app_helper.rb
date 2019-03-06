ENV['APP_ENV'] = 'test'
ENV['CONFIG_PATH'] = File.expand_path('../config.yml', __FILE__)

require 'webmock/rspec'
require 'fileutils'

require 'bundler/setup'
Bundler.require(:default, 'test')

require 'spec_helper'

require File.expand_path('../../app', __FILE__)

Dir[File.expand_path('../support/*.rb', __FILE__)].each do |path|
  load path
end

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.include Support::TimeHelper
  config.include Support::NetworkHelper
  config.include Support::DataHelper
end
