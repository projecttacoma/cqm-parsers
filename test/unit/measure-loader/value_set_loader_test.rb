require 'test_helper'
require 'vcr_setup.rb'

class VSACValueSetLoaderTest < Minitest::Test

  def setup
    @fixtures_path = File.join('test', 'fixtures', 'vs_loading')

    @measure_file_base = File.new File.join(@fixtures_path, 'DocofMeds_v5_1_Artifacts_updated.zip')
    @measure_file_with_profiles = File.new File.join(@fixtures_path, 'DocofMeds_v5_1_Artifacts_With_Profiles_updated.zip')
    @measure_file_version = File.new File.join(@fixtures_path, 'DocofMeds_v5_1_Artifacts_Version_updated.zip')
    @empty_measure_details = {}

    @vcr_options = {match_requests_on: [:method, :uri_no_st]}
  end

  def test_can_use_cache
    VCR.use_cassette('measure__test_can_use_cache') do
      vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
      vs_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      needed_value_sets = [{oid: "2.16.840.1.113883.3.117.1.7.1.292", version: nil, profile: nil}]

      valuesets = vs_loader.retrieve_and_modelize_value_sets_from_vsac(needed_value_sets)

      stub_request(:any, /\./).to_timeout # disable all network connections
      valuesets_again = vs_loader.retrieve_and_modelize_value_sets_from_vsac(needed_value_sets)
      WebMock.reset!

      assert_equal valuesets, valuesets_again
    end
  end

  def test_includedraft_and_no_profile_or_version
    # Expects that draft and default profile will be used
    VCR.use_cassette('vs_loading_draft_no_profile_version', @vcr_options) do
      vsac_options = { profile: APP_CONFIG['vsac']['default_profile'], include_draft: true }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_base, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 165, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_with_includedraft_and_a_profile
    # Expects that draft and default profile will be used, and provided Profile will be ignored
    VCR.use_cassette('vs_loading_draft_profile', @vcr_options) do
      vsac_options = { profile: APP_CONFIG['vsac']['default_profile'], include_draft: true }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_with_profiles, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 165, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_with_includedraft_and_a_version
    VCR.use_cassette('vs_loading_draft_verion', 
                     match_requests_on: [:method, :uri_no_st]) do
      vsac_options = { profile: APP_CONFIG['vsac']['default_profile'], include_draft: true }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_version, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 165, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_without_includedraft_and_no_profile_or_version
    VCR.use_cassette('vs_loading_no_profile_version', @vcr_options) do
      vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_version, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 165, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_with_measure_defined_and_no_backup_profile
    VCR.use_cassette('vs_loading_meausre_defined_no_backup_profile', @vcr_options) do
      vsac_options = { measure_defined: true }

      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_base, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 173, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_with_release
    VCR.use_cassette('vs_loading_release', @vcr_options) do
      vsac_options = { release: 'eCQM Update 2018 EP-EC and EH' }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_base, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 162, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_with_api_key
    VCR.use_cassette('vs_loading_with_apikey', @vcr_options) do
      vsac_options = { release: 'eCQM Update 2018 EP-EC and EH' }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: ENV['VSAC_API_KEY'])
      loader = Measures::CqlLoader.new(@measure_file_base, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 162, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_measure_defined_value_sets_defined_by_profile
    VCR.use_cassette('vs_loading_profile', @vcr_options) do
      vsac_options = { measure_defined: true }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_with_profiles, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 163, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_measure_defined_value_sets_defined_by_version
    VCR.use_cassette('vs_loading_version', @vcr_options) do
      vsac_options = { measure_defined: true }
      value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
      loader = Measures::CqlLoader.new(@measure_file_version, @empty_measure_details, value_set_loader)
      measure = loader.extract_measures[0]
      assert_equal 148, measure.value_sets.select { |vs| vs.oid == "2.16.840.1.113883.3.600.1.1834"}[0].concepts.size
    end
  end

  def test_loading_valueset_that_returns_an_empty_concept_list
    # DO NOT re-record this cassette. the response for this valueset may have changed.
    # As of 4/11/18 this value set uses a codesystem not in Latest eCQM profile and returns an empty concept list
    VCR.use_cassette('vs_loading_empty_concept_list', @vcr_options) do
      value_sets = [{ oid: '2.16.840.1.113762.1.4.1179.2'}]
      vsac_options = { profile: 'Latest eCQM', include_draft: true }

      error = assert_raises Util::VSAC::VSEmptyError do
        value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
        value_set_loader.retrieve_and_modelize_value_sets_from_vsac(value_sets)
      end
      assert_equal '2.16.840.1.113762.1.4.1179.2', error.oid
    end
  end

  def test_loading_valueset_that_causes_not_found_response
    VCR.use_cassette('vs_loading_not_found_response', @vcr_options) do
      value_sets = [{ oid: '2.16.840.1.113762.1.4.1179.2f'}]
      vsac_options = { profile: 'Latest eCQM', include_draft: true }

      error = assert_raises Util::VSAC::VSNotFoundError do
        value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: test_api_key)
        value_set_loader.retrieve_and_modelize_value_sets_from_vsac(value_sets)
      end
      assert_equal '2.16.840.1.113762.1.4.1179.2f', error.oid
    end
  end

  def test_loader_only_authenticates_if_needed
    # This should not use VCR, the idea is to show that the measure loading error occurs before
    # any network connection attempts. This tests the VSACValueSetLoader 'lazy' authentiacation.
    measure_file = File.new File.join(@fixtures_path, 'IETCQL_v5_0_missing_vs_oid_Artifacts.zip')
    value_set_loader = Measures::VSACValueSetLoader.new(options: {}, username: 'fake', password: 'fake')
    loader = Measures::CqlLoader.new(measure_file, {}, value_set_loader)
    assert_raises Measures::MeasureLoadingInvalidPackageException do
      loader.extract_measures
    end
  end
end
