module Measures
  module ValueSetHelpers
    class << self

      def set_data_criteria_code_list_ids(hqmf_model_hash, value_sets_from_single_code_references)
        # Loop over data criteria to search for data criteria that is using a single reference code.
        # Once found set the Data Criteria's 'code_list_id' to our fake oid. Do the same for source data criteria.
        hqmf_model_hash[:data_criteria].each do |data_criteria_name, data_criteria|
          next unless data_criteria[:inline_code_list] && !data_criteria[:code_list_id]
          # Check to see if inline_code_list contains the correct code_system and code for a direct reference code.
          data_criteria[:inline_code_list].each do |code_system, code_list|
            # Loop over all single code reference objects.
            value_sets_from_single_code_references.each do |value_set|
              # If Data Criteria contains a matching code system, check if the correct code exists in the data critera values.
              # If both values match, set the Data Criteria's 'code_list_id' to the single_code_object_guid.
              unless value_set.concepts.length == 1
                raise StandardError "This function should only be called on valuesets with one concept (single code references)."
              end
              concept = value_set.concepts[0]
              next unless concept.code_system_name.starts_with?(code_system.to_s) && code_list.include?(concept.code)
              data_criteria[:code_list_id] = value_set.oid
              # Modify the matching source data criteria
              hqmf_model_hash[:source_data_criteria]["#{data_criteria_name}_source".to_sym][:code_list_id] = value_set.oid
            end
          end
        end
      end

      # Adjusting value set version data. If version is profile, set the version to nil
      def modify_value_set_versions(elm)
        (elm.dig('library','valueSets','def') || []).each do |value_set|
          # If value set has a version and it starts with 'urn:hl7:profile:' then set to nil
          if value_set['version']&.include?('urn:hl7:profile:')
            value_set['profile'] = URI.decode(value_set['version'].split('urn:hl7:profile:').last)
            value_set['version'] = nil
          # If value has a version and it starts with 'urn:hl7:version:' then strip that and keep the actual version value.
          elsif value_set['version']&.include?('urn:hl7:version:')
            value_set['version'] = URI.decode(value_set['version'].split('urn:hl7:version:').last)
          end
        end
      end

      # Removes 'urn:oid:' from ELM
      def remove_urnoid(json)
        Utilities.deep_traverse_hash(json) { |hash, k, v| hash[k] = v.gsub('urn:oid:', '') if v.is_a?(String) }
      end

      def load_value_sets_and_process(cql_libraries, value_set_loader, measure_id = nil)
        elms = cql_libraries.map(&:elm)
        elm_value_sets = []
        elms.each do |elm|
          (elm.dig('library','valueSets','def') || []).each do |value_set|
            elm_value_sets << {oid: value_set['id'], version: value_set['version'], profile: value_set['profile']}
          end
        end

        value_set_models = value_set_loader.retrieve_and_modelize_value_sets_from_vsac(elm_value_sets, measure_id)

        # Get code systems and codes for all value sets in the elm.
        value_sets_from_single_code_references = make_fake_valuesets_from_single_code_references(elms)
        value_set_models.push(*value_sets_from_single_code_references)

        all_codes_and_code_names = get_all_codes_and_code_names(value_set_models)

        return {
          all_codes_and_code_names: all_codes_and_code_names.as_json, 
          value_sets_from_single_code_references: value_sets_from_single_code_references,
          value_set_models: value_set_models
        }
      end
      
      private

      def get_all_codes_and_code_names(value_sets)
        all_codes_and_code_names = {}
        value_sets.each do |value_set|
          code_sets = {}
          value_set.concepts.each do |concept|
            code_sets[concept.code_system_name] ||= []
            code_sets[concept.code_system_name] << concept.code
          end
          all_codes_and_code_names[value_set.oid] = code_sets
        end

        return all_codes_and_code_names
      end

      # Add single code references by finding the codes from the elm and creating new ValueSet objects
      # With a generated GUID as a fake oid.
      def make_fake_valuesets_from_single_code_references(elms)
        value_sets_from_single_code_references = []

        elms.each do |elm|
          # Loops over all single codes and saves them as fake valuesets.
          (elm.dig('library','codes','def') || []).each do |code_reference|
            # look up the referenced code system
            code_system_def = elm['library']['codeSystems']['def'].find { |code_sys| code_sys['name'] == code_reference['codeSystem']['name'] }
            # Generate a unique number as our fake "oid" based on parameters that identify the DRC
            code_hash = "drc-" + Digest::SHA2.hexdigest("#{code_system_def['id']}#{code_system_def['version']}#{code_reference['id']}")            

            concept = CQM::Concept.new(code: code_reference['id'],
                                       code_system_name: code_system_def['name'],
                                       code_system_version: code_system_def['version'],
                                       code_system_oid: code_system_def['id'],
                                       display_name: code_reference['name'])

            vs = CQM::ValueSet.new(oid: code_hash,
                                   display_name: code_reference['name'],
                                   version: '',
                                   concepts: [concept])

            value_sets_from_single_code_references << vs
          end
        end
        return value_sets_from_single_code_references
      end

    end
  end
end