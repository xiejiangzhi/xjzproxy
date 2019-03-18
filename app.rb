$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)

  # init sub module
  module Reslover; end
  class ProxyClient; end

  Dir[File.join($root, 'src/xjz/**/*.rb')].sort.each { |path| load path }
end
