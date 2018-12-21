# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "cqm-parsers"
  s.summary = "A library for parsing HQMF documents."
  s.description = "A library for parsing HQMF documents."
  s.email = "tacoma-list@lists.mitre.org"
  s.homepage = "https://github.com/projecttacoma/cqm-parsers"
  s.authors = ["The MITRE Corporation"]
  s.license = 'Apache-2.0'

  s.version = '1.0.0'

  s.add_dependency 'rest-client', '~>2.0.2'
  s.add_dependency 'erubis', '~> 2.7.0'
  s.add_dependency 'mongoid', '~> 6.4.2'
  s.add_dependency 'mongoid-tree', '~> 2.1.0'
  s.add_dependency 'activesupport', '~> 5.1.6'

  s.add_dependency 'uuid', '~> 2.3.7'
  s.add_dependency 'builder', '~> 3.1'
  s.add_dependency 'nokogiri', '~> 1.8.5'
  s.add_dependency 'highline', "~> 1.7.0"

  s.add_dependency 'rubyzip', '~> 1.2.2'
  s.add_dependency 'zip-zip', '~> 0.3'

  s.add_dependency 'log4r', '~> 1.1.10'
  s.add_dependency 'memoist', '~> 0.9.1'

  s.files = Dir.glob('lib/**/*.rb') + Dir.glob('lib/**/*.json') + Dir.glob('lib/**/*.mustache') + Dir.glob('lib/**/*.rake') + ["Gemfile", "README.md", "Rakefile"]
end
