require 'test_helper'
# require 'vcr_setup.rb'

class CompositeCQLLoaderTest < ActiveSupport::TestCase
  
  setup do
    @composite_cql_mat_export = File.new File.join('test', 'fixtures', 'measureloading', 'CMSAWA_v5_6_Artifacts.zip')
    # @missing_file_composite_cql_mat_export = File.new File.join('test', 'fixtures', 'CMSAWA_v5_6_Artifacts_missing_file.zip')
    # @missing_component_composite_cql_mat_export = File.new File.join('test', 'fixtures', 'CMSAWA_v5_6_Artifacts_missing_component.zip')
    # @missing_composite_files = File.new File.join('test', 'fixtures', 'CMSAWA_v5_6_Artifacts_missing_composite_files.zip')
  end

  # test "Verify the composite measure to be uploaded is valid" do
  #   is_valid = Measures::CqlLoader.mat_cql_export?(@composite_cql_mat_export)
  #   assert_equal true, is_valid
  # end

  # test "Flag when an invalid composite measure is provided" do
  #   is_valid = Measures::CqlLoader.mat_cql_export?(@missing_file_composite_cql_mat_export)
  #   assert_equal false, is_valid

  #   is_valid = Measures::CqlLoader.mat_cql_export?(@missing_composite_files)
  #   assert_equal false, is_valid
  # end


  test 'Loading a measure' do
    # VCR.use_cassette('what') do
      @measurefile = File.new File.join('test', 'fixtures', 'measureloading', 'CMS134v6.zip')

      dump_db
      user = User.new
      user.save

      measure_details = { 'episode_of_care'=> false }

      vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
      vsac_tgt = "TGT-2158989-fK4XmLHrhCUprHaODGvxIxBaxFui9my7jbxVqNBp77NEFzVRMG-cas"
      vsac_tgt_holder = { ticket: vsac_tgt, expires: Time.now + 8.hours }

      loader = Measures::CqlLoader.new(measure_details, vsac_options, vsac_tgt_holder)
      a = loader.extract_measures(@measurefile)
      binding.pry

      # Measures::CqlLoader.extract_measures(@cql_mat_export, user, measure_details, { profile: APP_CONFIG['vsac']['default_profile'] }, get_ticket_granting_ticket).each {|measure| measure.save}
      # assert_equal 1, CqlMeasure.all.count
      # measure = CqlMeasure.all.first
      # assert_equal 'Diabetes: Medical Attention for Nephropathy', measure.title
      # cql_statement_dependencies = measure.cql_statement_dependencies
      # assert_equal 3, cql_statement_dependencies.length
      # assert_equal 1, cql_statement_dependencies['Hospice'].length
      # assert_equal [], cql_statement_dependencies['Hospice']['Has Hospice']
    # end
  end


  # test 'Loading a Composite Measure' do
  #   # VCR.use_cassette('load_composite_measure') do
  #     dump_db
  #     user = User.new
  #     user.save

  #     measure_details = { 'episode_of_care'=> false }

  #     # Measures::CqlLoader.extract_measures(@composite_cql_mat_export, user, measure_details, { profile: APP_CONFIG['vsac']['default_profile'] }, get_ticket_granting_ticket).each {|measure| measure.save}
  #     vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
  #     vsac_ticket_granting_ticke = nil
  #     loader = Measures::CqlLoader.new(user, measure_details, vsac_options, nil)
  #     loader.extract_measures(@composite_cql_mat_export)



  #     assert_equal 8, CqlMeasure.all.count
  #     # Verify there is only one composite measure
  #     assert_equal 1, CqlMeasure.all.where(composite: true).count
  #     assert_equal 7, CqlMeasure.all.where(composite: false).count

  #     composite_measure = CqlMeasure.all.where(composite: true).first 
  #     component_measures = CqlMeasure.all.where(composite: false).all
  #     component_measures.each do |measure|
  #       # Verify the component contains the composite's hqmf_set_id
  #       assert measure.hqmf_set_id.include?(composite_measure.hqmf_set_id)
  #       # Verify each composite measure has a unique hqmf_set_id
  #       assert_equal 1, CqlMeasure.all.where(hqmf_set_id: measure.hqmf_set_id).count
  #       # Verify the composite's array of components is correct
  #       assert composite_measure.component_hqmf_set_ids.include?(measure.hqmf_set_id)
  #     end
  #     # Verify the composite is associated with each of the components
  #     assert_equal 7, composite_measure.component_hqmf_set_ids.count
  #   # end
  # end

  # test 'Loading an invalid composite measure that has a component measure with missing xml file' do
  #   VCR.use_cassette('load_composite_measure_with_missing_file') do
  #     dump_db
  #     user = User.new
  #     user.save

  #     measure_details = { 'episode_of_care'=> false }

  #     assert_raise Measures::MeasureLoadingException do
  #       Measures::CqlLoader.extract_measures(@missing_file_composite_cql_mat_export, user, measure_details, { profile: APP_CONFIG['vsac']['default_profile'] }, get_ticket_granting_ticket).each {|measure| measure.save}
  #     end
  #     assert_equal 0, CqlMeasure.all.count
  #   end
  # end

  # test 'Loading a composite measure with a missing component measure' do
  #   VCR.use_cassette('load_composite_measure_with_missing_component') do
  #     dump_db
  #     user = User.new
  #     user.save

  #     measure_details = { 'episode_of_care'=> false }

  #     assert_raise Measures::MeasureLoadingException do
  #       Measures::CqlLoader.extract_measures(@missing_component_composite_cql_mat_export, user, measure_details, { profile: APP_CONFIG['vsac']['default_profile'] }, get_ticket_granting_ticket).each {|measure| measure.save}
  #     end
  #     assert_equal 0, CqlMeasure.all.count
  #   end
  # end

  # test 'Loading an invalid composite measure that is missing the composite measure files' do
  #   VCR.use_cassette('load_composite_measure_with_missing_composite_files') do
  #     dump_db
  #     user = User.new
  #     user.save

  #     measure_details = { 'episode_of_care'=> false }

  #     assert_raise Measures::MeasureLoadingException do
  #       Measures::CqlLoader.extract_measures(@missing_composite_files, user, measure_details, { profile: APP_CONFIG['vsac']['default_profile'] }, get_ticket_granting_ticket).each {|measure| measure.save}
  #     end
  #     assert_equal 0, CqlMeasure.all.count
  #   end
  # end

  
end
