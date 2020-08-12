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
    skip "MAT-1175"
    measure_file = File.new File.join(@fixtures_path, 'not_mat_export.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal false, is_valid
  end

  def test_composite_measure_file_is_valid
    skip "Bonnie-on-FHIR does not support composite measures."
    measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal true, is_valid
  end

  def test_invalid_composite_measures
    skip "Bonnie-on-FHIR does not support composite measures."
    measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts_missing_composite_files.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal false, is_valid

    measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts_missing_file.zip')
    is_valid = Measures::MATMeasureFiles.valid_zip?(measure_file)
    assert_equal false, is_valid
  end

  def test_invalid_lib_fhir_version
    lib = JSON.parse File.new(File.join(@fixtures_path, "fhir", 'lib_invalid_fhir_version.json')).read
    fhir_lib = FHIR::Library.transform_json lib
    err = assert_raises Measures::MeasureLoadingInvalidPackageException do
      Measures::MATMeasureFiles.parse_lib_contents fhir_lib
    end
    assert err.message.include? "One or more Libraries FHIR version does not match FHIR"
  end

  def test_valid_lib_fhir_version_does_not_raise
    lib = JSON.parse File.new(File.join(@fixtures_path, "fhir", 'lib.json')).read
    fhir_lib = FHIR::Library.transform_json lib
    Measures::MATMeasureFiles.parse_lib_contents fhir_lib
  end
end
