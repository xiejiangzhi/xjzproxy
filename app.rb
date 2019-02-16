require './env'

require 'yaml'

require './src/server'
require './src/cert_gen'

$config = YAML.load_file(File.join($root, 'config/config.yml'))
$cert_gen = CertGen.new

t = Server.new.start
t.join

