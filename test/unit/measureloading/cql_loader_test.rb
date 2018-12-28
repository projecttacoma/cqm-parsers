require 'test_helper'
# require 'vcr_setup.rb'

class CQLLoaderTest < ActiveSupport::TestCase
  
  setup do
    @fixtures_path = File.join('test', 'fixtures', 'measureloading')
    @vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
    @vsac_options_w_draft = { include_draft: true, profile: APP_CONFIG['vsac']['default_profile'] }
    @vsac_tgt = get_ticket_granting_ticket_with_api_key
    @measure_details = { 'episode_of_care'=> false }
  end

  # DONE
  test 'Loading a measure that has a definition with the same name as a library definition' do
    # VCR.use_cassette('valid_vsac_response_hospice') do

      measure_file = File.new File.join(@fixtures_path, 'CMS134v6.zip')

      loader = Measures::CqlLoader.new(@measure_details, @vsac_options, @vsac_tgt)
      measures = loader.extract_measures(measure_file)

      assert_equal 1, measures.length
      measure = measures[0]
      # binding.pry
      assert_equal 'Diabetes: Medical Attention for Nephropathy', measure.title
      assert_equal 3, measure.cql_libraries.length
      hospice_deps = measure.cql_libraries.find_by(library_name: 'Hospice').statement_dependencies
      assert_equal 1, hospice_deps.length
      assert_equal [], hospice_deps.find_by(statement_name: 'Has Hospice').statement_references


    # end
  end

  # DONE
  test 'Loading a measure with a direct reference code handles the creation of code_list_id hash properly' do

    measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts_Update.zip')
    loader = Measures::CqlLoader.new(@measure_details, @vsac_options, @vsac_tgt)
    measures = loader.extract_measures(measure_file)

    # do first load
    # VCR.use_cassette('valid_vsac_response_158_update') do
    #   Measures::CqlLoader.extract_measures(direct_reference_mat_export, user, measure_details, { profile: APP_CONFIG['vsac']['default_profile'] }, get_ticket_granting_ticket).each {|measure| measure.save}
    # end
    measure = measures[0]

    # Confirm that the source data criteria with the direct reference code is equal to the expected hash
    assert_equal measure.source_data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D_source][:code_list_id], "drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381"
    assert_equal measure.data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D][:code_list_id], "drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381"

    # Re-load the Measure
    # VCR.use_cassette('valid_vsac_response_158_update') do
    #   Measures::CqlLoader.extract_measures(direct_reference_mat_export, user, measure_details, { profile: APP_CONFIG['vsac']['default_profile'] }, get_ticket_granting_ticket).each {|measure| measure.save}
    # end
    loader = Measures::CqlLoader.new(@measure_details, @vsac_options, @vsac_tgt)
    measures = loader.extract_measures(measure_file)
    measureAgain = measures[0]

    # Confirm that the Direct Reference Code, code_list_id hash is the same.
    assert_equal measureAgain.source_data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D_source][:code_list_id], "drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381"
    assert_equal measureAgain.data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D][:code_list_id], "drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381"

  end


  # THIS ERRORS VS NOT FOUND, ALSO IN ORIG
  # test 'Loading a measure with support libraries that dont have their define definitions used are still included in the dependencty structure as empty hashes' do
  #   # unused_library_mat_export = File.new File.join('test', 'fixtures', 'PVC2_v5_4_Unused_Support_Libraries.zip')
  #   # VCR.use_cassette('valid_vsac_response_pvc_unused_libraries') do

  #     measure_file = File.new File.join(@fixtures_path, 'PVC2_v5_4_Unused_Support_Libraries.zip')
  #     loader = Measures::CqlLoader.new(@measure_details, @vsac_options_w_draft, @vsac_tgt)
  #     measures = loader.extract_measures(measure_file)
  #     measure = measures[0]
  #     binding.pry

  #     # Confirm that the cql dependency structure has the same number of keys (libraries) as items in the elm array
  #     assert_equal measure.cql_statement_dependencies.count, measure.elm.count
  #     # Confirm the support library is an empty hash
  #     assert measure.cql_statement_dependencies['Hospice'].empty?
  #   # end
  # end

  # DONE
  test 'Loading measure with unique characters such as &amp; which should be displayed and stored as "&"' do
    # VCR.use_cassette('valid_vsac_response_special_characters') do
      
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options_w_draft, @vsac_tgt)
      measure_file = File.new File.join(@fixtures_path, 'TOB2_v5_5_Artifacts.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]
      
      annotations = measure.cql_libraries.find_by(library_name: 'TobaccoUseTreatmentProvidedorOfferedTOB2TobaccoUseTreatmentTOB2a').elm_annotations
      define_name = annotations[:statements][36][:define_name]
      clause_text = annotations[:statements][36][:children][0][:children][0][:children][0][:text]

      assert_not_equal 'Type of Tobacco Used - Cigar &amp; Pipe', define_name
      assert_equal 'Type of Tobacco Used - Cigar & Pipe', define_name
      assert !clause_text.include?('define "Type of Tobacco Used - Cigar &amp; Pipe"')
      assert clause_text.include?('define "Type of Tobacco Used - Cigar & Pipe"')
    # end
  end

  #####from load_mat_export_test file

  #DONE
  test "Loading a CQL Mat export zip file including draft, with VSAC credentials" do
    # VCR.use_cassette("valid_vsac_response_includes_draft") do

      loader = Measures::CqlLoader.new(@measure_details, @vsac_options_w_draft, @vsac_tgt)
      measure_file = File.new File.join(@fixtures_path, 'DRAFT_CMS2_CQL.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]

      assert_equal "Screening for Depression", measure.title
      assert_equal "40280582-5B4D-EE92-015B-827458050128", measure.hqmf_id
      assert_equal 1, measure.population_sets.size
      assert_equal 5, measure.population_criteria.keys.count
      assert_equal "C1EA44B5-B922-49C5-B41C-6509A6A86158", measure.hqmf_set_id
      for value_set in measure.value_sets
        assert_equal ("Draft-" + measure.hqmf_set_id), value_set.version
      end
    # end
  end

  # DONE
  test "Loading a CQL Mat export zip file, with VSAC credentials" do
    # VCR.use_cassette("valid_vsac_response") do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options_w_draft, @vsac_tgt)
      measure_file = File.new File.join(@fixtures_path, 'BCS_v5_0_Artifacts.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]
      # binding.pry

      assert_equal "BCSTest", measure.title
      assert_equal "40280582-57B5-1CC0-0157-B53816CC0046", measure.hqmf_id
      assert_equal 1, measure.population_sets.size
      assert_equal 4, measure.population_criteria.keys.count
    # end
  end


  # DONE
  test "Loading a MAT 5.4 CQL export zip file with VSAC credentials" do
    # VCR.use_cassette("valid_vsac_response_158") do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options, @vsac_tgt)
      measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]

      assert_equal "Test 158", measure.title
      assert_equal "40280582-5801-9EE4-0158-310E539D0327", measure.hqmf_id
      assert_equal "8F010DBB-CB52-47CD-8FE8-03A4F223D87F", measure.hqmf_set_id
      assert_equal 1, measure.population_sets.size
      assert_equal 4, measure.population_criteria.keys.count
      assert_equal 1, measure.cql_libraries.size
    # end
  end

  # DONE
  test "Loading a CQL Mat export with multiple libraries, with VSAC credentials" do
    # VCR.use_cassette("multi_library_webcalls") do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options, @vsac_tgt)
      measure_file = File.new File.join(@fixtures_path, 'bonnienesting01_fixed.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]

      assert_equal 4, measure.cql_libraries.size
      measure.cql_libraries.each do |cql_library|
        assert (cql_library.elm['library'].present?)
      end
      assert_equal "BonnieLib100", measure.cql_libraries[0].elm["library"]["identifier"]["id"]
      assert_equal "BonnieLib110", measure.cql_libraries[1].elm["library"]["identifier"]["id"]
      assert_equal "BonnieLib200", measure.cql_libraries[2].elm["library"]["identifier"]["id"]
      assert_equal "BonnieNesting01", measure.cql_libraries[3].elm["library"]["identifier"]["id"]
    # end
  end

end
