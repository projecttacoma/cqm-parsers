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

      measures.each { |m| CqlLoader.update_population_set_and_strat_titles(m, @measure_details[:population_titles]) }
      return measures
    end

    def self.update_population_set_and_strat_titles(measure, population_titles)
      # Sample population_titles: [pop set 1 title, pop set 2 title, pop set 1 strat 1 title,
      #                   pop set 1 strat 2 title, pop set 2 strat 1 title, pop set 2 strat 2 title]
      # Note RE composite measures: components and composite must have same population sets and strats
      return if population_titles.nil? || population_titles.empty?
      title_idx = 0
      measure.population_sets.each do |population_set|
        population_set.title = population_titles[title_idx] if population_titles[title_idx].present?
        title_idx += 1
        break if title_idx >= population_titles.size
      end

      return if title_idx >= population_titles.size

      measure.population_sets.flat_map(&:stratifications).each do |strat|
        strat.title = population_titles[title_idx] if population_titles[title_idx].present?
        title_idx += 1
        break if title_idx >= population_titles.size
      end
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
      elms = cql_libraries.map(&:elm)

      elm_valuesets = ValueSetHelpers.list_of_valuesets_referenced_by_elm(elms)
      verify_hqmf_valuesets_match_elm_valuesets(elm_valuesets, hqmf_model)
      value_set_models, all_codes_and_code_names, value_sets_from_single_code_references = 
        ValueSetHelpers.load_value_sets_and_process(elms, elm_valuesets, @value_set_loader, hqmf_model.hqmf_set_id)

      hqmf_model.backfill_patient_characteristics_with_codes(all_codes_and_code_names)
      ## this to_json is needed, it doesn't actually produce json, it just makes a hash that is better
      ## suited for our uses (e.g. source_data_criteria goes from an array to a hash keyed by id)
      hqmf_model_hash = hqmf_model.to_json.deep_symbolize_keys!
      ValueSetHelpers.set_data_criteria_code_list_ids(hqmf_model_hash, value_sets_from_single_code_references)
      
      measure = create_measure_from_hqmf(measure_files.hqmf_xml, hqmf_model_hash)
      value_set_models.each { |vsm| measure.value_sets.push vsm }
      measure.cql_libraries = cql_libraries
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

    def verify_hqmf_valuesets_match_elm_valuesets(elm_valuesets, measure_hqmf_model)
      # Exclude patient birthdate OID (2.16.840.1.113883.3.117.1.7.1.70) and patient expired
      # OID (2.16.840.1.113883.3.117.1.7.1.309) used by SimpleXML parser for AGE_AT handling
      # and bad oid protection in missing VS check
      missing = (measure_hqmf_model.all_code_set_oids - elm_valuesets.map {|v| v[:oid]} - ['2.16.840.1.113883.3.117.1.7.1.70', '2.16.840.1.113883.3.117.1.7.1.309'])
      raise MeasureLoadingInvalidPackageException.new("The HQMF file references the following valuesets not present in the CQL: #{missing}") unless missing.empty?
    end
  end
end
