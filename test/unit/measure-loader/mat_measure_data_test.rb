require 'test_helper'

class MATMeasureFilesTest < Minitest::Test
  
  def setup
    @fixtures_path = File.join('test', 'fixtures', 'measureloading')
  end

  def test_measure_uploaded_valid
    measure_file = File.new File.join(@fixtures_path, 'CMS134v6.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal true, is_valid
  end

  def test_flag_invalid_measure
    measure_file = File.new File.join(@fixtures_path, 'not_mat_export.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal false, is_valid
  end

  def test_composite_measure_file_is_valid
    measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal true, is_valid
  end

  def test_invalid_composite_measures
    measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts_missing_composite_files.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal false, is_valid

    measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts_missing_file.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal false, is_valid
  end

end
