$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)

  # init sub module
  module Reslover; end
  class ProxyClient; end
end

files = Dir[File.join($root, 'src/xjz/**/*.rb')].sort
orders = [
  /xjz\/core_ext/
]

orders.each do |regexp|
  files.delete_if do |path|
    if path =~ regexp
      load path
      true
    end
  end
end
files.each { |path| load path }
