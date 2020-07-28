require 'base64'

module Measures
  class BundleLoader

    def initialize(measure_zip, measure_details, value_set_loader = nil)
      @measure_zip = measure_zip
      @measure_details = measure_details.deep_symbolize_keys
      @vs_model_cache = {}
      @value_set_loader = value_set_loader
      @value_set_loader.vs_model_cache = @vs_model_cache if @value_set_loader.present?
    end

    # extracts & returns cqm measure, a wrapper augmenting the FHIR Measure model with Bonnie specific information.
    def extract_measures
      measure_files = MATMeasureFiles.create_from_zip_file(@measure_zip)
      measure_bundle = FHIR::BundleUtils.get_measure_bundle(measure_files)
      measure = create_measure(measure_bundle)
      measure.package = CQM::MeasurePackage.new(file: BSON::Binary.new(@measure_zip.read))
      measure
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

    # @deprecated
    # def create_measure_and_components(measure_files)
    #   top_level_library_ids = measure_files.cql_libraries.map { |lib| "#{lib.id}_v#{lib.version}" }
    #   add_component_cql_library_files_to_composite_measure_files(measure_files)
    #   measure = create_measure(measure_files)
    #   component_measures = create_component_measures(measure_files, measure.hqmf_set_id)
    #   measure.component_hqmf_set_ids = component_measures.map(&:hqmf_set_id)
    #   unset_top_level_flag_on_cql_libraries_imported_from_components(measure, top_level_library_ids)
    #
    #   return measure, component_measures
    # end

    # @deprecated
    # def create_component_measures(measure_files, composite_measure_hqmf_set_id)
    #   component_measures = measure_files.components.map { |comp_files| create_measure(comp_files) }
    #   component_measures.each do |component_measure|
    #     # Set the components' hqmf_set_id to: <composite_hqmf_set_id>&<component_hqmf_set_id>
    #     component_measure.hqmf_set_id = "#{composite_measure_hqmf_set_id}&#{component_measure.hqmf_set_id}"
    #     component_measure.component = true
    #     component_measure.composite_hqmf_set_id = composite_measure_hqmf_set_id
    #   end
    #   return component_measures
    # end

    # @deprecated
    # def unset_top_level_flag_on_cql_libraries_imported_from_components(composite_measure, top_level_library_ids)
    #   composite_measure.cql_libraries.each do |lib|
    #     unless "#{lib.library_name}_v#{lib.library_version}".in? top_level_library_ids
    #       lib.is_top_level = false # is_top_level defaults to true
    #     end
    #   end
    # end

    # @deprecated
    # def add_component_cql_library_files_to_composite_measure_files(measure_files)
    #   component_cql_library_files = measure_files.components.flat_map(&:cql_libraries)
    #   measure_files.cql_libraries.push(*component_cql_library_files)
    #   measure_files.cql_libraries.uniq! { |cl| cl.id + cl.version }
    #   return nil
    # end

    # Creates and returns a measure
    def create_measure(measure_bundle)
      measure_resource = FHIR::BundleUtils.get_resources_by_name(bundle: measure_bundle, name: 'Measure').first

      guid_identifier = get_guid_from_measure_resource(measure_resource)

      fhir_measure = FHIR::Measure.transform_json(measure_resource['resource'])

      library_resources = FHIR::BundleUtils.get_resources_by_name(bundle: measure_bundle, name: 'Library')
      libraries = library_resources.map {|library_resource| FHIR::Library.transform_json(library_resource['resource'])}

      cqm_measure = CQM::Measure.new(fhir_measure: fhir_measure,
                                     libraries: libraries)

      cqm_measure.cql_libraries = parse_cql_elm(libraries, fhir_measure.name.value, fhir_measure.version.value)
      elms = cqm_measure.cql_libraries.map(&:elm)
      elm_value_sets = ValueSetHelpers.unique_list_of_valuesets_referenced_by_elms(elms)
      cqm_measure.value_sets = ValueSetHelpers.make_fake_valuesets_from_drc(elms, @vs_model_cache)
      cqm_measure.value_sets.concat(@value_set_loader.retrieve_and_modelize_value_sets_from_vsac(elm_value_sets)) if @value_set_loader.present?

      cqm_measure.set_id = guid_identifier.upcase
      cqm_measure
    end

    def parse_cql_elm(libraries, measure_lib_name, measure_lib_version)
      logic_library_content = []
      libraries.each do |lib|
        logic_library_content << MATMeasureFiles::parse_cql_elm(lib)
      end

      elm_statement_dependencies = ElmDependencyFinder.find_dependencies(logic_library_content, measure_lib_name)

      logic_library_content.map do |lib_content|
        stmt_dependencies = elm_statement_dependencies[lib_content.id]
        is_main_cql_lib = lib_content.id == measure_lib_name && lib_content.version == measure_lib_version
        modelize_cql_library(lib_content, stmt_dependencies, is_main_cql_lib)
      end
    end

    def modelize_cql_library(cql_lib_files, cql_statement_dependencies, is_main_cql_lib)
      CQM::LogicLibrary.new(
        library_name: cql_lib_files.id,
        library_version: cql_lib_files.version,
        elm: cql_lib_files.elm,
        elm_annotations: ElmParser.parse(cql_lib_files.elm_xml),
        cql: cql_lib_files.cql,
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

    def get_guid_from_measure_resource(measure_resource)
      guid_identifier = measure_resource['resource']['identifier'].select{ |identifier|
        identifier['system'] == 'http://hl7.org/fhir/cqi/ecqm/Measure/Identifier/guid'
      }
      raise MeasureLoadingInvalidPackageException.new('GUID for measure is missing') if guid_identifier.empty?
      guid_identifier.first['value']
    end

    # @deprecated
    # def verify_hqmf_valuesets_match_elm_valuesets(elm_valuesets, measure_hqmf_model)
    #   # Exclude patient birthdate OID (2.16.840.1.113883.3.117.1.7.1.70) and patient expired
    #   # OID (2.16.840.1.113883.3.117.1.7.1.309) used by SimpleXML parser for AGE_AT handling
    #   # and bad oid protection in missing VS check
    #   missing = (measure_hqmf_model.all_code_set_oids - elm_valuesets.map {|v| v[:oid]} - ['2.16.840.1.113883.3.117.1.7.1.70', '2.16.840.1.113883.3.117.1.7.1.309'])
    #   raise MeasureLoadingInvalidPackageException.new("The HQMF file references the following valuesets not present in the CQL: #{missing}") unless missing.empty?
    # end
  end
end
