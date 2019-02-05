require 'test_helper'
require 'vcr_setup.rb'

class CQLLoaderTest < Minitest::Test
  
  def setup
    @fixtures_path = File.join('test', 'fixtures', 'measureloading')
    @vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
    @vsac_options_w_draft = { include_draft: true, profile: APP_CONFIG['vsac']['default_profile'] }
    @measure_details = { 'episode_of_care'=> false }

    @vcr_options = {match_requests_on: [:method, :uri_no_st]}
  end

  def test_invalid_composite_measure_with_component_measure_missing_xml_file
    VCR.use_cassette('measure__test_invalid_composite_measure_with_component_measure_missing_xml_file', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts_missing_file.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      assert_raises Measures::MeasureLoadingInvalidPackageException do
        loader.extract_measures
      end
    end
  end

  def test_invalid_composite_measure_with_missing_component_measure
    VCR.use_cassette('measure__invalid_composite_measure_with_missing_component_measure', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts_missing_component.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      assert_raises Measures::MeasureLoadingInvalidPackageException do
        loader.extract_measures
      end
    end
  end

  def test_invalid_composite_measure_with_missing_composite_measure_files
    VCR.use_cassette('measure__invalid_composite_measure_with_missing_composite_measure_files', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts_missing_composite_files.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      assert_raises Measures::MeasureLoadingInvalidPackageException do
        loader.extract_measures
      end
    end
  end

  def test_loading_composite_measure
    VCR.use_cassette('measure__load_composite_measure', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMSAWA_v5_6_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      assert_equal 8, measures.length      
      composite_measure = measures[7]
      component_measures = measures[0..6]

      assert_equal true, composite_measure.composite
      component_measures.each {|m| assert_equal false, m.composite}

      component_measures.each do |measure|
        assert measure.hqmf_set_id.include?(composite_measure.hqmf_set_id)
        assert composite_measure.component_hqmf_set_ids.include?(measure.hqmf_set_id)
      end
      assert_equal 7, composite_measure.component_hqmf_set_ids.count
    end
  end
end
