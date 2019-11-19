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
      measure_file = File.new File.join(@fixtures_path, 'CMS111_v5_6_Artifacts.zip')

      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
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
      assert_equal 'PopulationSet_1', population_set.population_set_id
      assert_equal 'Population Criteria Section', population_set.title
      assert population_set.populations.instance_of?(CQM::ContinuousVariablePopulationMap)
      assert_equal 'Initial Population', population_set.populations.IPP.statement_name
      assert_equal '93C1E91C-806B-4F57-946D-D145D1BD08E2', population_set.populations.IPP.hqmf_id
      assert_equal 'Measure Population', population_set.populations.MSRPOPL.statement_name
      assert_equal '4725E77E-3D0F-46AC-A175-8DEFDE19EC8A', population_set.populations.MSRPOPL.hqmf_id
      assert_equal 'Measure Population Exclusions', population_set.populations.MSRPOPLEX.statement_name
      assert_equal '31E49A75-5D9F-441D-96D0-FE2FED1B006B', population_set.populations.MSRPOPLEX.hqmf_id

      # check stratifications
      assert_equal 2, population_set.stratifications.size
      assert_equal 'PopulationSet_1_Stratification_1', population_set.stratifications[0].stratification_id
      assert_equal 'PopSet1 Stratification 1', population_set.stratifications[0].title
      assert_equal '4DB7BC72-5DD8-4EEB-AB62-D039567CF620', population_set.stratifications[0].hqmf_id
      assert_equal 'Stratification 1', population_set.stratifications[0].statement.statement_name
      assert_equal '4DB7BC72-5DD8-4EEB-AB62-D039567CF620', population_set.stratifications[0].statement.hqmf_id
      assert_equal 'MedianAdmitDecisionTimetoEDDepartureTimeforAdmittedPatients', population_set.stratifications[0].statement.library_name
      assert_equal 'PopulationSet_1_Stratification_2', population_set.stratifications[1].stratification_id
      assert_equal 'PopSet1 Stratification 2', population_set.stratifications[1].title
      assert_equal '46958FCE-9FF3-4F1A-89AB-0A21D1F47F52', population_set.stratifications[1].hqmf_id
      assert_equal 'Stratification 2', population_set.stratifications[1].statement.statement_name
      assert_equal '46958FCE-9FF3-4F1A-89AB-0A21D1F47F52', population_set.stratifications[1].statement.hqmf_id
      assert_equal 'MedianAdmitDecisionTimetoEDDepartureTimeforAdmittedPatients', population_set.stratifications[1].statement.library_name

      # check observation
      assert_equal population_set.observations.size, 1
      assert_equal 'Measure Observation', population_set.observations[0].observation_function.statement_name
      assert_equal '2D7701F3-F93D-4994-84F6-0FA00FAA81C9', population_set.observations[0].hqmf_id
      assert_equal 'Measure Population', population_set.observations[0].observation_parameter.statement_name

      # check SDE
      assert_equal ["SDE Ethnicity", "SDE Payer", "SDE Race", "SDE Sex"], population_set.supplemental_data_elements.map(&:statement_name)

      # check valuesets
      # note if you call value_sets.count or .size you will be making a db call
      assert_equal 10, measure.value_sets.each.count
    end
  end

  def test_population_titles
    VCR.use_cassette('measure__population_titles', @vcr_options) do
      measure_details = { 'episode_of_care'=> true, 'continuous_variable' => true, 'population_titles' => ['ps1','ps2','ps1strat1','ps1strat2','ps2strat1'] }
      measure_file = File.new File.join(@fixtures_path, 'CMS137v7.zip')

      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, measure_details, value_set_loader)
      measures = loader.extract_measures
      assert_equal 1, measures.length
      measure = measures[0]

      assert_equal 'ps1', measure.population_sets[0].title
      assert_equal 'ps2', measure.population_sets[1].title
      assert_equal 'ps1strat1', measure.population_sets[0].stratifications[0].title
      assert_equal 'ps1strat2', measure.population_sets[0].stratifications[1].title
      assert_equal 'ps2strat1', measure.population_sets[1].stratifications[0].title
      assert_equal 'PopSet2 Stratification 2', measure.population_sets[1].stratifications[1].title
    end
  end

  def test_definition_with_same_name_as_a_library_definition
    VCR.use_cassette('measure__definition_with_same_name_as_a_library_definition', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMS134v6.zip')

      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      assert_equal 1, measures.length
      measure = measures[0]

      assert_equal "CMS134v6", measure.cms_id
      assert_equal 'Diabetes: Medical Attention for Nephropathy', measure.title
      assert_equal 3, measure.cql_libraries.length
      hospice_deps = measure.cql_libraries.find_by(library_name: 'Hospice').statement_dependencies
      assert_equal 1, hospice_deps.length
      assert_equal [], hospice_deps.find_by(statement_name: 'Has Hospice').statement_references
    end
  end

  def test_source_data_criteria_creation
    VCR.use_cassette('measure__source_data_criteria_creation', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMS134v6.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      assert_equal 1, measures.length
      measure = measures[0]

      # when the same valueset is used for multiple source data criteria, make sure both are saved.
      intervention_dc = measure.source_data_criteria.select { |sdc| sdc.codeListId == '2.16.840.1.113762.1.4.1108.15' }
      assert_equal intervention_dc.map(&:qdmTitle), [
        'Intervention, Order',
        'Intervention, Performed'
      ]

      assert_equal measure.source_data_criteria.map(&:qdmTitle), [
        'Encounter, Performed',
        'Procedure, Performed',
        'Procedure, Performed',
        'Patient Characteristic Sex',
        'Encounter, Performed',
        'Medication, Active',
        'Diagnosis',
        'Encounter, Performed',
        'Diagnosis',
        'Encounter, Performed',
        'Intervention, Order',
        'Intervention, Performed',
        'Intervention, Performed',
        'Patient Characteristic Race',
        'Encounter, Performed',
        'Diagnosis',
        'Patient Characteristic Payer',
        'Encounter, Performed',
        'Diagnosis',
        'Intervention, Performed',
        'Encounter, Performed',
        'Procedure, Performed',
        'Patient Characteristic Ethnicity',
        'Laboratory Test, Performed',
        'Diagnosis',
        'Encounter, Performed',
        'Diagnosis'
      ]
      assert_equal measure.source_data_criteria[0].description, 'Encounter, Performed: Face-to-FaceInteraction'
      assert_equal measure.source_data_criteria[0].codeListId, '2.16.840.1.113883.3.464.1003.101.12.1048'
      assert_equal measure.source_data_criteria[0].hqmfOid, '2.16.840.1.113883.10.20.28.4.5'

      # Test direct reference code elements are filled with info from hitting vsac
      assert_equal measure.source_data_criteria[23].description, 'Laboratory Test, Performed: UrineProteinTests'
      assert_equal measure.source_data_criteria[23].codeListId, '2.16.840.1.113883.3.464.1003.109.12.1024'
      assert_equal measure.source_data_criteria[6].description, 'Diagnosis: KidneyFailure'
      assert_equal measure.source_data_criteria[6].codeListId, '2.16.840.1.113883.3.464.1003.109.12.1028'
    end
  end

  def test_direct_reference_code_handles_creation_of_codelistid_hash
    measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts_Update.zip')

    ['1','2'].each do |cassette_number|
      VCR.use_cassette('measure__direct_reference_code_handles_creation_of_codeListId_hash'+cassette_number, @vcr_options) do
        value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
        loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
        measures = loader.extract_measures
        measure = measures[0]

        # Confirm that the source data criteria with the direct reference code is equal to the expected hash
        assert_equal 'drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381', measure.source_data_criteria.select { |sdc| sdc.hqmfOid == '2.16.840.1.113883.10.20.28.4.42' }[0].codeListId
      end
    end
  end

  def test_unique_characters_stored_correctly
    VCR.use_cassette('measure__unique_characters_stored_correctly', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'TOB2_v5_5_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options_w_draft, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
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
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options_w_draft, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      measure = measures[0]

      assert_equal "Screening for Depression", measure.title
      assert_equal "40280582-5B4D-EE92-015B-827458050128", measure.hqmf_id
      assert_equal 1, measure.population_sets.size
      assert_equal 5, measure.population_criteria.keys.count
      assert_equal "C1EA44B5-B922-49C5-B41C-6509A6A86158", measure.hqmf_set_id
      measure.value_sets.each do |value_set|
        assert_equal ("Draft"), value_set.version
      end
    end
  end

  def test_measure
    VCR.use_cassette("measure__test_measure", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMS137v7.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options_w_draft, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      measure = measures[0]

      assert_equal 'Initiation and Engagement of Alcohol and Other Drug Dependence Treatment', measure.title
      assert_equal '40280382-6258-7581-0162-92A37A9B15DF', measure.hqmf_id
      assert_equal 2, measure.population_sets.size
      assert_equal 12, measure.population_criteria.keys.count
      assert_equal measure.cql_libraries.size, measure.cql_libraries.select(&:is_top_level).size
    end
  end

  def test_5_4_CQL_measure
    VCR.use_cassette("measure__test_5_4_CQL_measure", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
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

  def test_proportional_cv_measure
    VCR.use_cassette("measure__test_ratio_cv_measure", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'HyperG_v5_6_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      measure = measures[0]

      assert_equal 'Hospital Harm Hyperglycemia in Hospitalized Patients', measure.title
    end
  end

  def test_ratio_cv_measure
    VCR.use_cassette("measure__test_proportional_cv_measure", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CVmulti_v5_6_Artifacts.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      measure = measures[0]

      assert_equal 'CVmulti', measure.title
    end
  end

  def test_multiple_libraries
    VCR.use_cassette("measure__test_multiple_libraries", @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'bonnienesting01_updated.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
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

  def test_invalid_hqmf_elm_valueset_mismatch
    # in the CQL file, the 'Alcohol and Drug Dependence Treatment' value set oid was changed from
    # '2.16.840.1.113883.3.464.1003.106.12.1005' to '2.16.840.1.113883.3.464.1003.106.12.1001',
    # no changes in the HQMF.
    measure_file = File.new File.join(@fixtures_path, 'IETCQL_v5_0_missing_vs_oid_Artifacts.zip')
    value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: nil)
    loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
    assert_raises Measures::MeasureLoadingInvalidPackageException do
      loader.extract_measures
    end
  end

  def test_no_value_set_loader
    measure_file = File.new File.join(@fixtures_path, 'CMS158_v5_4_Artifacts.zip')
    loader = Measures::CqlLoader.new(measure_file, @measure_details)
    measures = loader.extract_measures
    measure = measures[0]

    # value sets should only contain the fake drc generated valuesets
    assert_equal ["drc-7ee14d7345fffbb069f02964b797739799926010eabc92da859da05e7ab54381"], measure.value_sets.map(&:oid)
    # source data criteria that rely on drc should still work
    assert_equal 1, measure.source_data_criteria.select { |sdc| sdc.description == "Laboratory Test, Performed: Hepatitis B virus surface Ag [Presence] in Serum" }.count
  end

  def test_extract_fields_from_single_code_reference_data_criteria
    measure_file = File.new File.join(@fixtures_path, 'CMS144_v5_8_Artifacts_20191104.zip')
    loader = Measures::CqlLoader.new(measure_file, @measure_details)
    measures = loader.extract_measures
    measure = measures[0]

    # value sets should only contain the fake drc generated valuesets
    assert_equal ["drc-c48426f721cede4d865df946157d5e2dc90bd32763ffcb982ca45b3bd97a29db",
                    "drc-7d7da17150a47034168a1372592dc014b452ce8d960b2ecd2b7f426cf4912dc3"], measure.value_sets.map(&:oid)
    # source data criteria that rely on drc should still work
    assert_equal 1, measure.source_data_criteria.select { |sdc| sdc.description == "Allergy/Intolerance: Substance with beta adrenergic receptor antagonist mechanism of action (substance)" }.count
    assert_equal 1, measure.source_data_criteria.select { |sdc| sdc.description == "Patient Characteristic Birthdate: Birth date" }.count
  end

  def test_negated_source_criteria_with_drc
    VCR.use_cassette('measure__negated_source_criteria_with_drc', @vcr_options) do
      measure_file = File.new File.join(@fixtures_path, 'CMS22v7.zip')
      value_set_loader = Measures::VSACValueSetLoader.new(options: @vsac_options, ticket_granting_ticket: get_ticket_granting_ticket_using_env_vars)
      loader = Measures::CqlLoader.new(measure_file, @measure_details, value_set_loader)
      measures = loader.extract_measures
      assert_equal 1, measures.length
      measure = measures[0]

      assert_equal measure.source_data_criteria.map(&:qdmTitle), [
        'Encounter, Performed',
        'Patient Characteristic Payer',
        'Intervention, Order',
        'Diagnostic Study, Order',
        'Patient Characteristic Sex',
        'Intervention, Order',
        'Intervention, Order',
        'Intervention, Order',
        'Intervention, Order',
        'Intervention, Order',
        'Intervention, Order',
        'Patient Characteristic Ethnicity',
        'Patient Characteristic Race',
        'Intervention, Order',
        'Laboratory Test, Order',
        'Medication, Order',
        'Diagnosis',
        'Physical Exam, Performed',
        'Physical Exam, Performed'
      ]

      # Test direct reference code elements are correct
      assert_equal measure.source_data_criteria[17].description, 'Physical Exam, Performed: Systolic blood pressure'
      assert_equal measure.source_data_criteria[17].codeListId, 'drc-a5a03993b6f7f05e4e80041738dcdf2bbc8b59dc7e387dbf85b6f58b8e78dcf9'
      assert_equal measure.source_data_criteria[18].description, 'Physical Exam, Performed: Diastolic blood pressure'
      assert_equal measure.source_data_criteria[18].codeListId, 'drc-c5d1ebc9ecb1d73d1ecec416e73261a59884cac2ccacc28edb1e9cd8b658c64e'
    end
  end
end
