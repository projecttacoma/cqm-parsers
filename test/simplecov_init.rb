require 'simplecov'
SimpleCov.start do
  add_filter "test/"
  track_files 'lib/**/*.rb'
end

module SimpleCov
  module Formatter
    class QualityFormatter
      def format(result)
        SimpleCov::Formatter::HTMLFormatter.new.format(result)
        File.open("coverage/covered_percent", "w") do |f|
          f.puts result.source_files.covered_percent.to_f
        end
      end
    end
  end
end

SimpleCov.formatter = SimpleCov::Formatter::QualityFormatter
SimpleCov.minimum_coverage(82.77)
