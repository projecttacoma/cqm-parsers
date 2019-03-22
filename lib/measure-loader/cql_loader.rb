module Measures
  class CqlLoader

    def initialize(measure_zip, measure_details, value_set_loader)
      @measure_zip = measure_zip
      @measure_details = measure_details.deep_symbolize_keys
      @vs_model_cache = {}
      value_set_loader.vs_model_cache = @vs_model_cache
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
      # measures.each { |m| translate_data_criteria_and_source_data_criteria(m) }
      return measures
    end

    def translate_data_criteria_and_source_data_criteria(measure)
      measure.data_criteria.each do |id, dc|
        measure.data_criteria[id] = translate_data_criteria(dc)
      end
      measure.source_data_criteria.each do |id, dc|
        measure.source_data_criteria[id] = translate_data_criteria(dc)
      end
      return nil
    end


    def translate_data_criteria(data_criteria)
      map = JSON.parse(File.read("lib/measure-loader/map_definition_and_status_to_model.json"))
      key = "#{data_criteria[:definition]}::#{data_criteria[:status]}"
      model_name = map[key]["model_name"]
      model = QDM.const_get(model_name).new(
        description: data_criteria[:description],
        codeListId: data_criteria[:code_list_id]
      )
      return model
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
      top_level_library_ids = measure_files.cql_libraries.map { |lib| "#{lib.id}_v#{lib.version}" }
      add_component_cql_library_files_to_composite_measure_files(measure_files)
      measure = create_measure(measure_files)
      component_measures = create_component_measures(measure_files, measure.hqmf_set_id)
      measure.component_hqmf_set_ids = component_measures.map(&:hqmf_set_id)
      unset_top_level_flag_on_cql_libraries_imported_from_components(measure, top_level_library_ids)

      return measure, component_measures
    end

    def create_component_measures(measure_files, composite_measure_hqmf_set_id)
      component_measures = measure_files.components.map { |comp_files| create_measure(comp_files) }
      component_measures.each do |component_measure|
        # Set the components' hqmf_set_id to: <composite_hqmf_set_id>&<component_hqmf_set_id>
        component_measure.hqmf_set_id = "#{composite_measure_hqmf_set_id}&#{component_measure.hqmf_set_id}"
        component_measure.component = true
        component_measure.composite_hqmf_set_id = composite_measure_hqmf_set_id
      end
      return component_measures
    end

    def unset_top_level_flag_on_cql_libraries_imported_from_components(composite_measure, top_level_library_ids)
      composite_measure.cql_libraries.each do |lib|
        unless "#{lib.library_name}_v#{lib.library_version}".in? top_level_library_ids
          lib.is_top_level = false # is_top_level defaults to true
        end
      end
    end

    def add_component_cql_library_files_to_composite_measure_files(measure_files)
      component_cql_library_files = measure_files.components.flat_map(&:cql_libraries)
      measure_files.cql_libraries.push(*component_cql_library_files)
      measure_files.cql_libraries.uniq! { |cl| cl.id + cl.version }
      return nil
    end

# #############################
#     def title
#       disp_value = attr_val("#{@code_list_xpath}/cda:displayName/@value")
#       # Attempt to pull display value from the localVariableName for
#       # MAT 5.3+ exports that appear to no longer include displayName for
#       # code entries.
#       # NOTE: A long term replacement for this and for other portions of the
#       # parsing process should involve reaching out to VSAC for oid information
#       # pulled from the CQL, and then to use that information while parsing.
#       unless disp_value.present?
#         # Grab the localVariableName from the XML
#         disp_value = attr_val('./cda:localVariableName/@value')
#         # Grab everything before the first underscore
#         disp_value = disp_value.partition('_').first unless disp_value.nil?
#       end
#       @title || disp_value || @description || id # allow defined titles to take precedence
#     end
#     def retrieve_title_and_description_for_model
#       # remove * Value Set from title
#       title_match = title.match(/(.*) \w+ [Vv]alue [Ss]et/)
#       @title = title_match[1] if title_match && title_match.length > 1
      
#       @description = "#{@description}: #{title}"
#     end
#     def extract_description
#       if @variable
#         encoded_name = attr_val('./cda:localVariableName/@value')
#         encoded_name = DataCriteriaMethods.extract_description_for_variable(encoded_name) if encoded_name
#         return encoded_name if encoded_name.present?
#         attr_val("./#{CRITERIA_GLOB}/cda:id/@extension")
#       else
#         attr_val("./#{CRITERIA_GLOB}/cda:text/@value") ||
#           attr_val("./#{CRITERIA_GLOB}/cda:title/@value") ||
#           attr_val("./#{CRITERIA_GLOB}/cda:id/@extension")
#       end
#     end
#     # Use the new MAT feature to extract the human generated (or computer generated) variable names from the xml.
#     def self.extract_description_for_variable(encoded_name)
#       if encoded_name.match(/^qdm_var_/)
#         # Strip out initial qdm_var_ string, trailing _*, and possible occurrence reference
#         encoded_name.gsub!(/^qdm_var_|/, '')
#         encoded_name.gsub!(/Occurrence[A-Z]of/, '')
#         # This code needs to handle measures created before the MAT added variable name hints; for those, don't strip
#         # the final identifier
#         unless encoded_name.match(/^(SATISFIES ALL|SATISFIES ANY|UNION|INTERSECTION)/)
#           encoded_name.gsub!(/_[^_]+$/, '')
#         end
#         encoded_name
#       elsif encoded_name.match(/^localVar_/)
#         encoded_name.gsub!(/^localVar_/, '')
#         encoded_name
#       end
#     end
#     @variable = DataCriteriaMethods.extract_variable(@local_variable_name, @id)
#     def self.extract_variable(local_variable_name, id)
#       variable = (local_variable_name =~ /.*qdm_var_/).present? unless local_variable_name.blank?
#       variable ||= (id =~ /.*qdm_var_/).present? unless id.blank?
#       variable
#     end
# ############################

    # Creates and returns a measure
    def create_measure(measure_files)
      hqmf_model = HQMF::Parser::V2CQLParser.new.parse(measure_files.hqmf_xml)

      # update the valueset info in each elm (update version and remove urn:oid)
      measure_files.cql_libraries.each { |cql_lib_files| modify_elm_valueset_information(cql_lib_files.elm) }
      cql_libraries = create_cql_libraries(measure_files.cql_libraries, hqmf_model.cql_measure_library)
      elms = cql_libraries.map(&:elm)

      elm_valuesets = ValueSetHelpers.unique_list_of_valuesets_referenced_by_elms(elms)
      verify_hqmf_valuesets_match_elm_valuesets(elm_valuesets, hqmf_model)
      value_set_models, all_codes_and_code_names, value_sets_from_single_code_references =
        ValueSetHelpers.load_value_sets_and_process(elms, elm_valuesets, @value_set_loader, @vs_model_cache)

      hqmf_model.backfill_patient_characteristics_with_codes(all_codes_and_code_names)
      ## this to_json is needed, it doesn't actually produce json, it just makes a hash that is better
      ## suited for our uses (e.g. source_data_criteria goes from an array to a hash keyed by id)
      hqmf_model_hash = hqmf_model.to_json.deep_symbolize_keys!


      measure = create_measure_from_hqmf(measure_files.hqmf_xml, hqmf_model_hash)
      value_set_models.each { |vsm| measure.value_sets.push vsm }
      measure.cql_libraries = cql_libraries

      measure.source_data_criteria = SourceDataCriteriaLoader.new(measure_files.hqmf_xml, value_sets_from_single_code_references).extract_data_criteria
      measure.composite = measure_files.components.present?

      return measure
    end

    def create_measure_from_hqmf(hqmf_xml, hqmf_model_hash)
      measure = CQM::Measure.new(HQMFMeasureLoader.extract_basic_fields(hqmf_xml))
      HQMFMeasureLoader.add_stuff_to_measure_model(measure, hqmf_xml, hqmf_model_hash)
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
