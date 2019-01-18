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

  def test_stratifications_and_observations
    VCR.use_cassette('measure__stratifications_and_observations', @vcr_options) do
      measure_details = { 'episode_of_care'=> true, 'continuous_variable' => true }
      # measure_file = File.new File.join(@fixtures_path, 'CMS32v7.zip')
      measure_file = File.new File.join(@fixtures_path, 'CMS111_v5_6_Artifacts.zip')

      value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options, get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, measure_details, value_set_loader)
      measures = loader.extract_measures
      assert_equal 1, measures.length
      measure = measures[0]

      assert_equal 'CONTINUOUS_VARIABLE', measure.measure_scoring
      assert_equal 'EPISODE_OF_CARE', measure.calculation_method

      assert_equal 2, measure.cql_libraries.size

      # check the main library name and find new library structure using it
      assert_equal 'MedianAdmitDecisionTimetoEDDepartureTimeforAdmittedPatients', measure.main_cql_library
      
      # check the new library structure
      main_library = measure.cql_libraries.select(&:is_main_library).first
      assert(!main_library.nil?)
      assert_equal 'MedianAdmitDecisionTimetoEDDepartureTimeforAdmittedPatients', main_library.library_name
      assert_equal '7.3.002', main_library.library_version
      assert_equal 16, main_library.statement_dependencies.size
      assert main_library.cql.starts_with?('library MedianAdmitDecisionTimetoEDDepartureTimeforAdmittedPatients')

      # check the references used by the "Initial Population"
      ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population' }.first
      assert(!ipp_dep.nil?)
      assert_equal 2, ipp_dep.statement_references.size
      assert_equal ["Inpatient Encounter", "ED Visit with Admit Order"], ipp_dep.statement_references.map(&:statement_name)

      # check population set
      assert_equal 1, measure.population_sets.size
      population_set = measure.population_sets[0]
      assert_equal 'PopulationCriteria1', population_set.population_set_id
      assert_equal 'Population Criteria Section', population_set.title
      assert population_set.populations.instance_of?(CQM::ContinuousVariablePopulationMap)
      assert_equal 'Initial Population', population_set.populations.IPP.statement_name
      assert_equal 'Measure Population', population_set.populations.MSRPOPL.statement_name
      assert_equal 'Measure Population Exclusions', population_set.populations.MSRPOPLEX.statement_name

      # check stratifications
      assert_equal 2, population_set.stratifications.size
      assert_equal '1', population_set.stratifications[0].stratification_id
      assert_equal 'Stratification 1', population_set.stratifications[0].title
      assert_equal 'Stratification 1', population_set.stratifications[0].statement.statement_name
      assert_equal 'MedianAdmitDecisionTimetoEDDepartureTimeforAdmittedPatients', population_set.stratifications[0].statement.library_name
      assert_equal '2', population_set.stratifications[1].stratification_id
      assert_equal 'Stratification 2', population_set.stratifications[1].title
      assert_equal 'Stratification 2', population_set.stratifications[1].statement.statement_name
      assert_equal 'MedianAdmitDecisionTimetoEDDepartureTimeforAdmittedPatients', population_set.stratifications[1].statement.library_name

      # check observation
      assert_equal population_set.observations.size, 1
      assert_equal 'Measure Observation', population_set.observations[0].observation_function.statement_name
      assert_equal 'Measure Population', population_set.observations[0].observation_parameter.statement_name

      # check SDE
      assert_equal ["SDE Ethnicity", "SDE Payer", "SDE Race", "SDE Sex"], population_set.supplemental_data_elements.map(&:statement_name)

      # check valuesets
      # note if you call value_sets.count or .size you will be making a db call
      assert_equal 12, measure.value_sets.each.count
    end
  end

  def test_definition_with_same_name_as_a_library_definition
    VCR.use_cassette('measure__definition_with_same_name_as_a_library_definition', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMS134v6.zip')

      value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options, get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
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
      VCR.use_cassette('measure__direct_reference_code_handles_creation_of_codeListId_hash'+cassette_number, @vcr_options) do
        value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options, get_ticket_granting_ticket)
        loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
        measures = loader.extract_measures
        measure = measures[0]
    
        # Confirm that the source data criteria with the direct reference code is equal to the expected hash
        assert_equal 'drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381', measure.source_data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D_source][:code_list_id]
        assert_equal 'drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381', measure.data_criteria[:prefix_5195_3_LaboratoryTestPerformed_70C9F083_14BD_4331_99D7_201F8589059D][:code_list_id]
      end
    end
  end

  def test_unique_characters_stored_correctly
    VCR.use_cassette('measure__unique_characters_stored_correctly', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'TOB2_v5_5_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options_w_draft, get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      measure = measures[0]
      
      annotations = measure.cql_libraries.find_by(library_name: 'TobaccoUseTreatmentProvidedorOfferedTOB2TobaccoUseTreatmentTOB2a').elm_annotations
      define_name = annotations[:statements][36][:define_name]
      clause_text = annotations[:statements][36][:children][0][:children][0][:children][0][:text]

      assert(define_name != 'Type of Tobacco Used - Cigar &amp; Pipe')
      assert_equal 'Type of Tobacco Used - Cigar & Pipe', define_name
      assert !clause_text.include?('define "Type of Tobacco Used - Cigar &amp; Pipe"')
      assert clause_text.include?('define "Type of Tobacco Used - Cigar & Pipe"')
    end
  end

  def test_measure_including_draft
    VCR.use_cassette("measure__measure_including_draft", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'DRAFT_CMS2_CQL.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options_w_draft, get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
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
    VCR.use_cassette("measure__test_measure", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'BCS_v5_0_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options_w_draft, get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      measure = measures[0]

      assert_equal "BCSTest", measure.title
      assert_equal "40280582-57B5-1CC0-0157-B53816CC0046", measure.hqmf_id
      assert_equal 1, measure.population_sets.size
      assert_equal 4, measure.population_criteria.keys.count
    end
  end

  def test_5_4_CQL_measure
    VCR.use_cassette("measure__test_5_4_CQL_measure", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options, get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
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
    VCR.use_cassette("measure__test_multiple_libraries", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'bonnienesting01_fixed.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(@vsac_options, get_ticket_granting_ticket)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
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
