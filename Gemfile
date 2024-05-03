source 'https://rubygems.org'

gemspec :development_group => :test

gem 'mongoid', '> 6.0.5', '< 9.0.0'

# gem 'cqm-models', git: 'https://github.com/projecttacoma/cqm-models.git', branch: 'master'
# gem 'cqm-models', :path => '../cqm-models'

group :development, :test do
  gem 'bundler-audit'
  gem 'rubocop', '~> 0.63.0', require: false
  gem 'byebug'
  gem 'pry'
  gem 'pry-nav'
end

group :development do
  gem 'rake'
end

group :test do
  gem 'factory_bot'
  gem 'tailor', '~> 1.1.2'
  gem 'cane', '~> 2.3.0'
  gem 'codecov'
  gem 'simplecov', :require => false
  gem 'webmock'
  gem 'minitest', '~> 5.3'
  gem 'minitest-reporters'
  gem 'awesome_print', :require => 'ap'
  gem 'vcr'
end
