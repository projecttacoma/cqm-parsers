module Measures
  class CqlLoader

    def initialize(measure_zip, measure_details, value_set_loader)
      @measure_zip = measure_zip
      @measure_details = measure_details.deep_symbolize_keys
      @value_set_loader = value_set_loader
    end

    # Returns an array of measures, will contain a single measure if it is a non-composite measure
    def extract_measures
      measure_files = MATMeasureFiles.create_from_zip_file(@measure_zip) 

      measures = []
      if measure_files.components.present?
        measure, component_measures = create_measure_and_components(measure_files)
        measures.push(*component_measures)
      else
        measure = create_measure(measure_files)
      end
      measure.package = CQM::MeasurePackage.new(file: BSON::Binary.new(@measure_zip.read))
      measures << measure
      return measures
    end

    private

    def create_measure_and_components(measure_files)
      add_component_cql_library_files_to_composite_measure_files(measure_files)
      measure = create_measure(measure_files)
      component_measures = measure_files.components.map { |comp_files| create_measure(comp_files) }
      component_measures.each do |component_measure|
        # Set the components' hqmf_set_id to: <composite_hqmf_set_id>&<component_hqmf_set_id>
        component_measure.hqmf_set_id = measure.hqmf_set_id + '&' + component_measure.hqmf_set_id
        component_measure.component = true
        component_measure.composite_hqmf_set_id = measure.hqmf_set_id
      end
      measure.component_hqmf_set_ids = component_measures.map(&:hqmf_set_id)
      return measure, component_measures
    end

    def add_component_cql_library_files_to_composite_measure_files(measure_files)
      component_cql_library_files = measure_files.components.flat_map(&:cql_libraries)
      measure_files.cql_libraries.push(*component_cql_library_files)
      measure_files.cql_libraries.uniq! { |cl| cl.id + cl.version }
      return nil
    end

    # Creates and returns a measure 
    def create_measure(measure_files)
      hqmf_model = HQMF::Parser::V2CQLParser.new.parse(measure_files.hqmf_xml)

      # update the valueset info in each elm (update version and remove urn:oid)
      measure_files.cql_libraries.each { |cql_lib_files| modify_elm_valueset_information(cql_lib_files.elm) }
      cql_libraries = create_cql_libraries(measure_files.cql_libraries, hqmf_model.cql_measure_library)
      vs_items = ValueSetHelpers.load_value_sets_and_process(cql_libraries, @value_set_loader, hqmf_model.hqmf_set_id)
      hqmf_model.backfill_patient_characteristics_with_codes(vs_items[:all_codes_and_code_names])
      ## this to_json is needed, it doesn't actually produce json, it just makes a hash that is better
      ## suited for our uses (e.g. source_data_criteria goes from an array to a hash keyed by id)
      hqmf_model_hash = hqmf_model.to_json.deep_symbolize_keys!
      ValueSetHelpers.set_data_criteria_code_list_ids(hqmf_model_hash, vs_items[:value_sets_from_single_code_references])

      measure = create_measure_from_hqmf(measure_files.hqmf_xml, hqmf_model_hash)
      measure.cql_libraries = cql_libraries
      vs_items[:value_set_models].each { |vsm| measure.value_sets.push vsm }
      measure.composite = measure_files.components.present?

      return measure
    end

    def create_measure_from_hqmf(hqmf_xml, hqmf_model_hash)
      measure = HQMFMeasureLoader.create_measure_model(hqmf_xml, hqmf_model_hash)
      measure.calculation_method = @measure_details[:episode_of_care] ? 'EPISODE_OF_CARE' : 'PATIENT'
      measure.calculate_sdes = @measure_details[:calculate_sdes]
      return measure
    end

    def create_cql_libraries(cql_library_files, main_cql_lib)
      cql_statement_dependencies_all_libs = ElmDependencyFinder.find_dependencies(cql_library_files, main_cql_lib)

      cql_libraries = cql_library_files.map do |cql_lib_files|
        cql_statement_dependencies = cql_statement_dependencies_all_libs[cql_lib_files.id]
        is_main_cql_lib = cql_lib_files.id == main_cql_lib
        modelize_cql_library(cql_lib_files, cql_statement_dependencies, is_main_cql_lib)
      end
      return cql_libraries
    end

    def modelize_cql_library(cql_lib_files, cql_statement_dependencies, is_main_cql_lib)
      return CQM::CQLLibrary.new(
        library_name: cql_lib_files.id,
        library_version: cql_lib_files.version,
        elm: cql_lib_files.elm,
        cql: cql_lib_files.cql,
        elm_annotations: ElmParser.parse(cql_lib_files.elm_xml),
        statement_dependencies: modelize_cql_statement_dependencies(cql_statement_dependencies),
        is_main_library: is_main_cql_lib
      )
    end

    def modelize_cql_statement_dependencies(cql_statment_deps)
      return cql_statment_deps.map do |name, refs|
        refs = refs.map { |ref| CQM::StatementReference.new(ref) }
        CQM::StatementDependency.new(statement_name: name, statement_references: refs)
      end
    end

    def modify_elm_valueset_information(elm)
      ValueSetHelpers.remove_urnoid(elm)
      ValueSetHelpers.modify_value_set_versions(elm)
      return nil
    end

  end
end
