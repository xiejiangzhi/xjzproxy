eval File.read(File.expand_path('../Gemfile.prod', __FILE__))

group :development do
  # debug
  gem 'pry'
  gem 'pry-byebug'

  # tools
  gem 'rake'
  gem 'gem-licenses'
  gem 'uglifier', '~> 4.1.20' # compress js

  # testing
  gem 'rspec', '~> 3.8.0'
  gem 'webmock', '~> 3.5.1'
  gem 'super_diff'

  gem 'rubocop', '~> 0.71.0'
end

group :license_server do
  gem 'bloomfilter-rb', github: 'xiejiangzhi/bloomfilter-rb', ref: 'e6907fd'
  gem 'puma', '~> 3.12.1'
end
