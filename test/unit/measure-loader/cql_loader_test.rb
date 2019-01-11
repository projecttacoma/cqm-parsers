require 'test_helper'
require 'vcr_setup.rb'

class CQLLoaderTest < Minitest::Test
  
  def setup
    @fixtures_path = File.join('test', 'fixtures', 'measureloading')
    @vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
    @vsac_options_w_draft = { include_draft: true, profile: APP_CONFIG['vsac']['default_profile'] }
    @measure_details = { 'episode_of_care'=> false }
  end

  def test_stratifications_and_observations
    VCR.use_cassette('measure__stratifications_and_observations', 
                     match_requests_on: [:method, :uri_no_st]) do
      measure_details = { 'episode_of_care'=> true, 'continuous_variable' => true }
      measure_file = File.new File.join(@fixtures_path, 'CMS32v7.zip')
      loader = Measures::CqlLoader.new(measure_details, @vsac_options, get_ticket_granting_ticket)
      measures = loader.extract_measures(measure_file)
      assert_equal 1, measures.length
      measure = measures[0]

      assert_equal measure.measure_scoring, 'CONTINUOUS_VARIABLE'
      assert_equal measure.calculation_method, 'EPISODE_OF_CARE'

      assert_equal measure.cql_libraries.size, 1

      # check the main library name and find new library structure using it
      assert_equal measure.main_cql_library, 'MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients'
      
      # check the new library structure
      main_library = measure.cql_libraries.select(&:is_main_library).first
      assert(!main_library.nil?)
      assert_equal main_library.library_name, 'MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients'
      assert_equal main_library.library_version, '7.2.002'
      assert_equal main_library.statement_dependencies.size, 13
      assert main_library.cql.starts_with?('library MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients')
      assert_equal main_library.is_main_library, true

      # check the references used by the "Initial Population"
      ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population' }.first
      assert(!ipp_dep.nil?)
      assert_equal ipp_dep.statement_references.size, 1
      assert ipp_dep.statement_references.map(&:statement_name).include?('ED Visit')

      # check population set
      assert_equal measure.population_sets.size, 1
      population_set = measure.population_sets[0]
      assert_equal population_set.id, 'PopulationCriteria1'
      assert_equal population_set.title, 'Population Criteria Section'
      assert population_set.populations.instance_of?(CQM::ContinuousVariablePopulationMap)
      assert_equal population_set.populations.IPP.statement_name, 'Initial Population'
      assert_equal population_set.populations.MSRPOPL.statement_name, 'Measure Population'
      assert_equal population_set.populations.MSRPOPLEX.statement_name, 'Measure Population Exclusions'

      # check stratifications
      assert_equal population_set.stratifications.size, 3
      assert_equal population_set.stratifications[0].title, 'Stratification 1'
      assert_equal population_set.stratifications[0].statement.statement_name, 'Stratification 1'
      assert_equal population_set.stratifications[0].statement.library_name, 'MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients'
      assert_equal population_set.stratifications[1].title, 'Stratification 2'
      assert_equal population_set.stratifications[1].statement.statement_name, 'Stratification 2'
      assert_equal population_set.stratifications[1].statement.library_name, 'MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients'
      assert_equal population_set.stratifications[2].title, 'Stratification 3'
      assert_equal population_set.stratifications[2].statement.statement_name, 'Stratification 3'
      assert_equal population_set.stratifications[2].statement.library_name, 'MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients'

      # check observation
      assert_equal population_set.observations.size, 1
      assert_equal population_set.observations[0].observation_function.statement_name, 'Measure Observation'
      assert_equal population_set.observations[0].observation_parameter.statement_name, 'Measure Population'

      # check SDE
      assert_equal population_set.supplemental_data_elements.size, 4
      assert_equal population_set.supplemental_data_elements[0].statement_name, 'SDE Ethnicity'
      assert_equal population_set.supplemental_data_elements[1].statement_name, 'SDE Payer'
      assert_equal population_set.supplemental_data_elements[2].statement_name, 'SDE Race'
      assert_equal population_set.supplemental_data_elements[3].statement_name, 'SDE Sex'

      # check valuesets
      # note if you call value_sets.count or .size you will be making a db call
      assert_equal measure.value_sets.each.count, 9
    end
  end

  def test_definition_with_same_name_as_a_library_definition
    VCR.use_cassette('measure__definition_with_same_name_as_a_library_definition', 
                     match_requests_on: [:method, :uri_no_st]) do
      measure_file = File.new File.join(@fixtures_path, 'CMS134v6.zip')
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options, get_ticket_granting_ticket)
      measures = loader.extract_measures(measure_file)
      assert_equal 1, measures.length
      measure = measures[0]

      assert_equal 'Diabetes: Medical Attention for Nephropathy', measure.title
      assert_equal 3, measure.cql_libraries.length
      hospice_deps = measure.cql_libraries.find_by(library_name: 'Hospice').statement_dependencies
      assert_equal 1, hospice_deps.length
      assert_equal [], hospice_deps.find_by(statement_name: 'Has Hospice').statement_references
    end
  end

  def test_direct_reference_code_handles_creation_of_codelistid_hash
    measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts_Update.zip')
    
    ['1','2'].each do |cassette_number|
      VCR.use_cassette('measure__direct_reference_code_handles_creation_of_codeListId_hash'+cassette_number,
                       match_requests_on: [:method, :uri_no_st]) do
        loader = Measures::CqlLoader.new(@measure_details, @vsac_options, get_ticket_granting_ticket)
        measures = loader.extract_measures(measure_file)
        measure = measures[0]
    
        # Confirm that the source data criteria with the direct reference code is equal to the expected hash
        assert_equal measure.source_data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D_source][:code_list_id], "drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381"
        assert_equal measure.data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D][:code_list_id], "drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381"
      end
    end
  end

  def test_unique_characters_stored_correctly
    VCR.use_cassette('measure__unique_characters_stored_correctly',
                     match_requests_on: [:method, :uri_no_st]) do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options_w_draft, get_ticket_granting_ticket)
      measure_file = File.new File.join(@fixtures_path, 'TOB2_v5_5_Artifacts.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]
      
      annotations = measure.cql_libraries.find_by(library_name: 'TobaccoUseTreatmentProvidedorOfferedTOB2TobaccoUseTreatmentTOB2a').elm_annotations
      define_name = annotations[:statements][36][:define_name]
      clause_text = annotations[:statements][36][:children][0][:children][0][:children][0][:text]

      assert(define_name != 'Type of Tobacco Used - Cigar &amp; Pipe')
      assert_equal define_name, 'Type of Tobacco Used - Cigar & Pipe'
      assert !clause_text.include?('define "Type of Tobacco Used - Cigar &amp; Pipe"')
      assert clause_text.include?('define "Type of Tobacco Used - Cigar & Pipe"')
    end
  end

  def test_measure_including_draft
    VCR.use_cassette("measure__measure_including_draft",
                     match_requests_on: [:method, :uri_no_st]) do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options_w_draft, get_ticket_granting_ticket)
      measure_file = File.new File.join(@fixtures_path, 'DRAFT_CMS2_CQL.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]

      assert_equal "Screening for Depression", measure.title
      assert_equal "40280582-5B4D-EE92-015B-827458050128", measure.hqmf_id
      assert_equal 1, measure.population_sets.size
      assert_equal 5, measure.population_criteria.keys.count
      assert_equal "C1EA44B5-B922-49C5-B41C-6509A6A86158", measure.hqmf_set_id
      measure.value_sets.each do |value_set|
        assert_equal ("Draft-" + measure.hqmf_set_id), value_set.version
      end
    end
  end

  def test_measure
    VCR.use_cassette("measure__test_measure",
                     match_requests_on: [:method, :uri_no_st]) do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options_w_draft, get_ticket_granting_ticket)
      measure_file = File.new File.join(@fixtures_path, 'BCS_v5_0_Artifacts.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]

      assert_equal "BCSTest", measure.title
      assert_equal "40280582-57B5-1CC0-0157-B53816CC0046", measure.hqmf_id
      assert_equal 1, measure.population_sets.size
      assert_equal 4, measure.population_criteria.keys.count
    end
  end

  def test_5_4_CQL_measure
    VCR.use_cassette("measure__test_5_4_CQL_measure",
                     match_requests_on: [:method, :uri_no_st]) do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options, get_ticket_granting_ticket)
      measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]

      assert_equal "Test 158", measure.title
      assert_equal "40280582-5801-9EE4-0158-310E539D0327", measure.hqmf_id
      assert_equal "8F010DBB-CB52-47CD-8FE8-03A4F223D87F", measure.hqmf_set_id
      assert_equal 1, measure.population_sets.size
      assert_equal 4, measure.population_criteria.keys.count
      assert_equal 1, measure.cql_libraries.size
    end
  end

  def test_multiple_libraries
    VCR.use_cassette("measure__test_multiple_libraries",
                     match_requests_on: [:method, :uri_no_st]) do
      loader = Measures::CqlLoader.new(@measure_details, @vsac_options, get_ticket_granting_ticket)
      measure_file = File.new File.join(@fixtures_path, 'bonnienesting01_fixed.zip')
      measures = loader.extract_measures(measure_file)
      measure = measures[0]

      assert_equal 4, measure.cql_libraries.size
      measure.cql_libraries.each do |cql_library|
        assert(cql_library.elm['library'].present?)
      end
      assert_equal "BonnieLib100", measure.cql_libraries[0].elm["library"]["identifier"]["id"]
      assert_equal "BonnieLib110", measure.cql_libraries[1].elm["library"]["identifier"]["id"]
      assert_equal "BonnieLib200", measure.cql_libraries[2].elm["library"]["identifier"]["id"]
      assert_equal "BonnieNesting01", measure.cql_libraries[3].elm["library"]["identifier"]["id"]
    end
  end

end
