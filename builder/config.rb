require 'bundler/setup'
require 'erb'
require 'yaml'

def load_yaml(path, erb: true)
  data = File.read(path)
  if erb
    erb = ERB.new(data)
    erb.filename = path
    data = erb.result
  end
  YAML.load(data)
end

$root = File.expand_path('../..', __FILE__)
$releases_dir = File.join($root, 'releases')
$config = load_yaml(File.join($root, 'build.yml'))

puts "Config: \n#{$config.to_yaml}\n\n"

