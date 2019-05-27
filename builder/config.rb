require 'bundler'
require 'erb'
require 'yaml'

def load_yaml(path, erb: true)
  data = File.read(path)
  data = load_erb(path, data) if erb
  YAML.load(data)
end

def load_erb(path, data = nil)
  data ||= File.read(path)
  erb = ERB.new(data)
  erb.filename = path
  erb.result
end

$root = File.expand_path('../..', __FILE__)
$releases_dir = File.join($root, 'releases')
$config = load_yaml(File.join($root, 'build.yml'))

puts "Config: \n#{$config.to_yaml}\n\n"

