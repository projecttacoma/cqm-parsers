require 'test_helper'
require 'vcr_setup.rb'
require 'json'

class ElmDependencyFinderTest < Minitest::Test
  
  def setup
    @fixtures_path = File.join('test', 'fixtures', 'measureloading')
  end

  def test_finding_deps_for_composite_elms
    elms = JSON.parse(File.read(File.join(@fixtures_path, 'composite_measure_elms.json')))
    cql_library_files = elms.map { |elm| Measures::MATMeasureFiles::CqlLibraryFiles.new(nil,nil,nil,elm,nil) }
    found_deps = Measures::ElmDependencyFinder.find_dependencies(cql_library_files, "AWATestComposite")
    expected_deps = JSON.parse(File.read(File.join(@fixtures_path,'composite_measure_expected_deps.json')))

    assert_equal expected_deps.deep_symbolize_keys, found_deps.deep_symbolize_keys
  end
end
