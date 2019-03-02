ENV['APP_ENV'] = 'test'
ENV['CONFIG_PATH'] = File.expand_path('../config.yml', __FILE__)

require 'spec_helper'
require 'fileutils'

require File.expand_path('../../app', __FILE__)

RSpec.configure do |config|
end
