$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)

  # init sub module
  module Reslover; end
  class ProxyClient; end

  Dir[File.join($root, 'src/xjz/**/*.rb')].sort.each { |path| load path }
end

$config['.api_projects'] = $config['projects'].map do |p|
  ap = Xjz::ApiProject.new(p)
  if errs = ap.errors
    Xjz::Logger[:auto].error { "Failed to load project '#{p}'\n#{errs.join("\n")}" }
    nil
  else
    ap
  end
rescue => e
  Xjz::Logger[:auto].error { e.log_inspect }
end.compact
