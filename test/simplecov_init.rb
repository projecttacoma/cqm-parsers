require 'simplecov'
require 'codecov'

SimpleCov.start do
  add_filter "test/"
  track_files 'lib/**/*.rb'
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([SimpleCov::Formatter::HTMLFormatter,SimpleCov::Formatter::Codecov])
