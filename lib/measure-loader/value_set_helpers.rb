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

      # Add single code references(DRC) by finding the codes from the elm and creating new ValueSet objects
      # With a generated GUID as a fake oid.
      def make_fake_valuesets_from_drc(elms, vs_model_cache)
        value_sets_from_single_code_references = []

        elms.each do |elm|
          # Loops over all single codes and saves them as fake ValueSets.
          (elm.dig('library','codes','def') || []).each do |code_reference|
            # look up the referenced code system
            code_system_def = elm['library']['codeSystems']['def'].find { |code_sys| code_sys['name'] == code_reference['codeSystem']['name'] }
            # Generate a unique number as our fake "oid" based on parameters that identify the DRC
            code_hash = "drc-" + Digest::SHA2.hexdigest("#{code_system_def['id']}#{code_system_def['version']}#{code_reference['id']}")

            cache_key = [code_hash, '']
            if vs_model_cache[cache_key].nil?
              vs_compose = prepare_value_set_compose(code_reference, code_system_def)
              vs_model_cache[cache_key] = FHIR::ValueSet.new(
                name: FHIR::PrimitiveString.transform_json(code_reference['name'], nil),
                title: FHIR::PrimitiveString.transform_json(code_reference['display'], nil),
                version: FHIR::PrimitiveString.new(value: ''),
                compose: vs_compose,
                fhirId: code_hash,
                url: FHIR::PrimitiveUri.transform_json("urn:uuid:#{SecureRandom.uuid}", nil)
              )
            end
            value_sets_from_single_code_references << vs_model_cache[cache_key]
          end
        end
        value_sets_from_single_code_references
      end

      def prepare_value_set_compose(code_reference, code_system_def)
        vs_concept = FHIR::ValueSetComposeIncludeConcept.new(
          code: FHIR::PrimitiveCode.transform_json(code_reference['id'], nil),
          display: FHIR::PrimitiveString.transform_json(code_reference['name'], nil)
        )
        codeSystemUri = code_system_def['id']
        codeSystemVersion = code_system_def['version']
        vsc_include = FHIR::ValueSetComposeInclude.new(
          system: FHIR::PrimitiveUri.transform_json(codeSystemUri, nil),
          version: FHIR::PrimitiveString.transform_json(codeSystemVersion, nil),
          concept: [vs_concept]
        )
        FHIR::ValueSetCompose.new(include: [vsc_include])
      end

      # Override with a value from config settings
      # Spreadsheet Example: https://docs.google.com/spreadsheets/d/15Tje3oiUfYgU24RiX-fUs-hH08dFOvW7_ysyAN8vxuc/edit#gid=0
      # Spreadsheet's JSON:  https://spreadsheets.google.com/feeds/list/15Tje3oiUfYgU24RiX-fUs-hH08dFOvW7_ysyAN8vxuc/od6/public/values?alt=json
      def spreadsheet_location_config
        'https://spreadsheets.google.com/feeds/list/15Tje3oiUfYgU24RiX-fUs-hH08dFOvW7_ysyAN8vxuc/od6/public/values?alt=json'
      end

      def code_systems_mappings()
        expires_in = 86400 # cache expiry time: 24 hours
        spreadsheet_location = spreadsheet_location_config
        CacheUtils::Cache.fetch 'code_system_mappings', expires_in do
          begin
            response = Typhoeus.get spreadsheet_location
            code_systems = { 'by_name' => {}, 'by_oid' => {} }
            JSON.parse(response.body)['feed']['entry'].each do |e|
              # gsx$oid - Code system OID
              # gsx$codesystemname - Code system name in MAT & VSAC
              # gsx$fhircodesystemname - Code system name in FHIR & Bonnie
              # gsx$url - Code system uri in FHIR 4
              code_system_oid = e['gsx$oid']['$t'].sub('urn:oid:', '').strip
              code_system_url = e['gsx$url']['$t']
              code_systems['by_oid'][code_system_oid] = code_system_url unless code_system_oid.blank?
              code_systems['by_name'][e['gsx$codesystemname']['$t']] = code_system_url if e.has_key?('gsx$codesystemname') && !e['gsx$codesystemname']['$t'].blank?
              code_systems['by_name'][e['gsx$fhircodesystemname']['$t']] = code_system_url if e.has_key?('gsx$fhircodesystemname') && !e['gsx$fhircodesystemname']['$t'].blank?
            end
            code_systems
          rescue Exception => e
            puts e.message
            raise Measures::RestException.new("An error occurred while fetching the code system mappings, please try later.")
          end
        end
      end
    end
  end
end
