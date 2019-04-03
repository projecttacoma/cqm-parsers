module Measures
  module ValueSetHelpers
    class << self

      # Adjusting value set version data. If version is profile, set the version to nil
      def modify_value_set_versions(elm)
        (elm.dig('library','valueSets','def') || []).each do |value_set|
          # If value set has a version and it starts with 'urn:hl7:profile:' then set to nil
          if value_set['version']&.include?('urn:hl7:profile:')
            value_set['profile'] = URI.decode_www_form_component(value_set['version'].split('urn:hl7:profile:').last)
            value_set['version'] = nil
          # If value has a version and it starts with 'urn:hl7:version:' then strip that and keep the actual version value.
          elsif value_set['version']&.include?('urn:hl7:version:')
            value_set['version'] = URI.decode_www_form_component(value_set['version'].split('urn:hl7:version:').last)
          end
        end
      end

      # Removes 'urn:oid:' from ELM
      def remove_urnoid(json)
        Utilities.deep_traverse_hash(json) { |hash, k, v| hash[k] = v.gsub('urn:oid:', '') if v.is_a?(String) }
      end

      def unique_list_of_valuesets_referenced_by_elms(elms)
        elm_value_sets = []
        elms.each do |elm|
          elm.dig('library','valueSets','def')&.each do |value_set|
            elm_value_sets << {oid: value_set['id'], version: value_set['version'], profile: value_set['profile']}
          end
        end
        elm_value_sets.uniq!
        return elm_value_sets
      end

      def load_value_sets_and_process(elms, elm_valuesets, value_set_loader, vs_model_cache)
        value_set_models = value_set_loader.retrieve_and_modelize_value_sets_from_vsac(elm_valuesets)

        # Get code systems and codes for all value sets in the elm.
        value_sets_from_single_code_references = make_fake_valuesets_from_single_code_references(elms, vs_model_cache)
        value_set_models.push(*value_sets_from_single_code_references)

        all_codes_and_code_names = get_all_codes_and_code_names(value_set_models)

        return value_set_models, all_codes_and_code_names.as_json, value_sets_from_single_code_references
      end
      
      # Add single code references by finding the codes from the elm and creating new ValueSet objects
      # With a generated GUID as a fake oid.
      def make_fake_valuesets_from_single_code_references(elms, vs_model_cache)
        value_sets_from_single_code_references = []

        elms.each do |elm|
          # Loops over all single codes and saves them as fake valuesets.
          (elm.dig('library','codes','def') || []).each do |code_reference|
            # look up the referenced code system
            code_system_def = elm['library']['codeSystems']['def'].find { |code_sys| code_sys['name'] == code_reference['codeSystem']['name'] }
            # Generate a unique number as our fake "oid" based on parameters that identify the DRC
            code_hash = "drc-" + Digest::SHA2.hexdigest("#{code_system_def['id']}#{code_system_def['version']}#{code_reference['id']}")

            cache_key = [code_hash, '']
            if vs_model_cache[cache_key].nil?
              concept = CQM::Concept.new(code: code_reference['id'],
                                         code_system_name: code_system_def['name'],
                                         code_system_version: code_system_def['version'],
                                         code_system_oid: code_system_def['id'],
                                         display_name: code_reference['name'])
              vs_model_cache[cache_key] = CQM::ValueSet.new(oid: code_hash,
                                                            display_name: code_reference['name'],
                                                            version: '',
                                                            concepts: [concept])
            end
            value_sets_from_single_code_references << vs_model_cache[cache_key]
          end
        end
        return value_sets_from_single_code_references
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

    end
  end
end