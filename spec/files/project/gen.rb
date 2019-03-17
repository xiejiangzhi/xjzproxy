#! /usr/bin/env ruby

require 'fileutils'
require 'yaml'

dir = File.expand_path('../', __FILE__)
data = YAML.load_file(File.join(dir, '../project.yml'))

Dir[File.join(dir, '**/*.{yml,yaml}')].each { |f| FileUtils.rm(f) }

FileUtils.cp(File.join(dir, '../test.rb'), './test.rb')

[
  ['api.yml', { 'apis' => data['apis'] }],
  ['config.yml', { 'project' => data['project'], 'plugins' => data['plugins'] }],
  ['res/r1.yml', { 'responses' => Hash[data['responses'].to_a[0..0]] }],
  ['res/r2.yaml', { 'responses' => Hash[data['responses'].to_a[1..-1]] }],
  ['res/p.yml', { 'partials' => Hash[data['partials'].to_a[0..0]] }],
  ['other/p.yaml', { 'partials' => Hash[data['partials'].to_a[1..-1]] }],
  ['other/types.yml', { 'types' => data['types'] }]
].each do |path, pdata|
  puts "Write #{path}:\n#{pdata}"
  File.write(File.join(dir, path), pdata.to_yaml)
end
