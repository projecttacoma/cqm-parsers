module Measures
  class CqlLoader




    def initialize(user, measure_details, vsac_options, vsac_ticket_granting_ticket)
      @user = user
      @measure_details = measure_details.deep_symbolize_keys
      @vsac_options = vsac_options
      @vsac_ticket_granting_ticket = vsac_ticket_granting_ticket

      @value_set_loader = Measure::ValueSetLoader.new(vsac_options, vsac_ticket_granting_ticket, user)
    end

    # Returns an array of measures
    # Single measure returned into the array if it is a non-composite measure
    def self.extract_measures(measure_zip)

      #note you can do like JSON.parse(blob, {:symbolize_keys  => true})

      starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      measure_artifacts = MeasureArtifacts.create_from_zip_file(measure_zip) 
      
      ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      elapsed = ending - starting
      puts "###################### ELAPSED = #{elapsed}" 
      require 'pry'
      binding.pry
      


      component_cql_library_artifacts = measure_artifacts.components.flat_map { |cm| cm.cql_library_artifacts }
      measure_artifacts.cql_library_artifacts.push(*component_cql_library_artifacts)
      measure_artifacts.cql_library_artifacts.uniq! { |cla| cla.id + cla.version }


      component_measures = []
      measure = nil
      begin
        measure_artifacts.components.each do |component_artifacts|
          component_measures << create_measure(component_artifacts)
        end
        measure = create_measure(measure_artifacts)
      rescue => e
        component_measures.each { |cm| cm.delete }
        raise e
      end

      # Create, associate and save the measure package.
      measure_package = CqlMeasurePackage.new(file: BSON::Binary.new(measure_zip.read()))
      measure.package = measure_package
      measure.package.save 

      component_measures.each do |component_measure|
        # Update the components' hqmf_set_id, formatted as follows:
        #   <composite_hqmf_set_id>&<component_hqmf_set_id>
        component_measure.hqmf_set_id = measure.hqmf_set_id + '&' + component_measure.hqmf_set_id
        component_measure.component = true;
        # Associate the component with the composite
        measure.component_hqmf_set_ids.push(component_measure.hqmf_set_id)
      end

      # Put measure (and component measures) into an array to return
      measures = component_measures << measure
      return measures
    end

    # Creates and returns a measure 
    def self.create_measure(measure_artifacts)
      # measure_artifacts  -->  attr_accessor :hqmf_xml, :cql_libraries, :human_readable, :components

      hqmf_model = Measures::Loader.parse_hqmf_model(hqmf_xml)
      // todo above func must take in nokogiri_xml

      # Get main measure from hqmf parser
      main_cql_library = hqmf_model.cql_measure_library


      
      all_codes_and_code_names = Measures::ValueSetManager.load_value_sets_and_process(elms, @value_set_loader, @user, hqmf_model.hqmf_set_id)

      hqmf_model.backfill_patient_characteristics_with_codes(all_codes_and_code_names)

      # Set the code list ids of data criteria and source data criteria that use direct reference codes to GUIDS.

      ## this to_json is needed, it doesn't actually produce json, it just makes a hash that is better
      ## suited for our uses (e.g. source_data_criteria goes from an array to a hash keyed by id,
      ## and other transforms)
      hqmf_model_hash = hqmf_model.to_json.deep_symbolize_keys!
      set_data_criteria_code_list_ids(hqmf_model_hash, single_code_references)

      
      # Create CQL Measure
      measure_scoring = if measure_details[:continuous_variable] then 'CONTINUOUS_VARIABLE' else 'PROPORTION' end
      measure = Measures::Loader.load_hqmf_cql_model_json(hqmf_model_hash, @user, cql_artifacts, measure_scoring)

 

      cql_definition_dependency_structure = ElmDependencyFinder.get_dependencies(elms, main_cql_library)
      measure.cql_libraries = measure_artifacts.map { |ma| create_cql_library(ma.cql_library_artifacts, cql_definition_dependency_structure) }


      # fix up statement names in cql_statement_dependencies to not use periods <<WRAP 1>>
      # this is matched with an UNWRAP in MeasuresController in the bonnie project
      Measures::MongoHashKeyWrapper::wrapKeys cql_definition_dependency_structure ???


      measure.composite = composite_measure?(measure_dir)
      measure.calculation_method = if measure_details[:episode_of_care] then 'EPISODE_OF_CARE' else 'PATIENT' end
      measure.calculate_sdes = measure_details[:calculate_sdes]
      measure.measure_scoring = measure_scoring
      measure
    end


    def self.create_cql_library(cql_library_artifacts, cql_definition_dependency_structure)
      modify_elm_vs_stuff(cql_library_artifacts.elm)
      cql_library = CQM::CQLLibrary.new(
        library_name: cql_library_artifacts.id,
        library_version: cql_library_artifacts.version,
        elm: cql_library_artifacts.elm,
        cql: cql_library_artifacts.cql
        elm_annotations: CqlElm::Parser.parse(cql_library_artifacts.elm_annotations)
        statement_dependencies: cql_definition_dependency_structure[cql_library_artifacts.id]
      )

      return cql_library
    end

    def modify_elm_vs_stuff(elm)
      Measures::ValueSetStuff.remove_urnoid(elm)
      Measures::ValueSetStuff.modify_value_set_versions(elm)
      return nil
    end






  end
end
