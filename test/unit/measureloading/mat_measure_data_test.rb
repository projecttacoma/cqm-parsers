require 'test_helper'
# require 'vcr_setup.rb'

class MATMeasureFilesTest < ActiveSupport::TestCase
  
  setup do
    @fixtures_path = File.join('test', 'fixtures', 'measureloading')
  end

  test "Verify the composite measure to be uploaded is valid" do
    measure_file = File.new File.join(@fixtures_path, 'CMS134v6.zip')
    is_valid = Measures::MATMeasureFiles.is_valid_zip?(measure_file)
    assert_equal true, is_valid
  end

  test "Flag when an invalid composite measure is provided" do
    measure_file = File.new File.join(@fixtures_path, 'not_mat_export.zip')
    is_valid = Measures::MATMeasureFiles.is_valid_zip?(measure_file)
    assert_equal false, is_valid
  end
end