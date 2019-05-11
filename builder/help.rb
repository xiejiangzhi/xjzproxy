require 'bundler/setup'
require 'erb'
require 'yaml'
require 'uglifier'

def load_yaml(path)
  erb = ERB.new(File.read(path))
  erb.filename = path
  YAML.load(erb.result)
end

$root = File.expand_path('../..', __FILE__)
$releases_dir = File.join($root, 'releases')
$config = load_yaml(File.join($root, 'build.yml'))

puts "Config: \n#{$config.to_yaml}\n\n"

def cmd(str, quiet: false)
  puts "$ #{str}" unless quiet
  exit 1 unless Kernel.system(str)
end
