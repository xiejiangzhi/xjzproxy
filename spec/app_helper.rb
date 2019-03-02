ENV['APP_ENV'] = 'test'
ENV['CONFIG_PATH'] = File.expand_path('../config.yml', __FILE__)

require 'spec_helper'
require 'fileutils'

require File.expand_path('../../app', __FILE__)

Dir[File.expand_path('../support/*.rb', __FILE__)].each do |path|
  load path
end

require File.expand_path('../../app', __FILE__)

RSpec.configure do |config|
  config.include Support::TimeHelper
end
