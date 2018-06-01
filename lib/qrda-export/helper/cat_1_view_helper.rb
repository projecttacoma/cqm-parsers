module Qrda
  module Export
    module Helper
      module Cat1ViewHelper

        def random_id
          UUID.generate
        end

        def object_id
          self[:_id]['$oid']
        end

        def submission_program
          @submission_program
        end

        def provider
          JSON.parse(@provider.to_json) if @provider
        end

        def provider_npi
          @provider['cda_identifiers'].map { |cda| cda['extension'] if cda['root'] == '2.16.840.1.113883.4.6' }.compact.first
        end

        def provider_tin
          @provider['cda_identifiers'].map { |cda| cda['extension'] if cda['root'] == '2.16.840.1.113883.4.2' }.compact.first
        end

        def provider_ccn
          @provider['cda_identifiers'].map { |cda| cda['extension'] if cda['root'] == '2.16.840.1.113883.4.336' }.compact.first
        end

        def provider_type_code
          @provider['specialty']
        end

        def mrn
          @patient.extendedData.medical_record_number
        end

        def given_name
          @patient.givenNames.join(' ')
        end

        def family_name
          @patient.familyName
        end

        def birthdate
          @patient.birthDatetime.to_formatted_s(:number)
        end

        def gender
          @patient.dataElements.where(:hqmfOid => '2.16.840.1.113883.10.20.28.3.55').first.dataElementCodes.first['code']
        end

        def race
          @patient.dataElements.where(:hqmfOid => '2.16.840.1.113883.10.20.28.3.59').first.dataElementCodes.first['code']
        end

        def ethnic_group
          @patient.dataElements.where(:hqmfOid => '2.16.840.1.113883.10.20.28.3.56').first.dataElementCodes.first['code']
        end

        def insurance_provider
          @insurance_provider
        end

        def insurance_provider_code_and_code_system
          "code=\"#{self['codes'].values.first[0]}\" codeSystem=\"#{code_system_oid(self['codes'].keys.first)}\" codeSystemName=\"#{self['codes'].keys.first}\""
        end

        def measures
          @measures.only(:hqmf_id, :hqmf_set_id, :description).as_json
        end

        def negation_ind
          self[:negationRationale].nil? ? "" : "negationInd=\"true\""
        end

        def negated
          self[:negationRationale].nil? ? false : true
        end

        def has_multiple_codes
          self[:dataElementCodes].size > 1 ? true : false
        end

        def code_system_oid(name)
          Qrda::Export::Helper::CodeSystemHelper.oid_for_code_system(name)
        end

        def code_and_codesystem
          "code=\"#{self['code']}\" codeSystem=\"#{code_system_oid(self['codeSystem'])}\" codeSystemName=\"#{self['codeSystem']}\""
        end

        def primary_code_and_codesystem
          "code=\"#{self[:dataElementCodes][0]['code']}\" codeSystem=\"#{code_system_oid(self[:dataElementCodes][0]['codeSystem'])}\" codeSystemName=\"#{self[:dataElementCodes][0]['codeSystem']}\""
        end

        def translation_codes_and_codesystem_list
          translation_list = ""
          self[:dataElementCodes].each_with_index do |dec, index|
            next if index == 0
            translation_list += "<translation code=\"#{self[:dataElementCodes][index]['code']}\" codeSystem=\"#{code_system_oid(self[:dataElementCodes][index]['codeSystem'])}\" codeSystemName=\"#{self[:dataElementCodes][index]['codeSystem']}\"/>"
          end
          translation_list
        end

        def result_value
          if self['result'].is_a? Array
            return result_value_as_string(self['result'][0])
          elsif self['result'].is_a? Hash
            return result_value_as_string(self['result'])
          elsif !self['result'].nil?
            return "<value xsi:type=\"PQ\" value=\"#{self['result']}\"/>"
          end
          "<value xsi:type=\"CD\" nullFlavor=\"UNK\"/>"
        end

        def result_value_as_string(result)
          if result['code']
            return "<value xsi:type=\"CD\" code=\"#{result['code']}\" codeSystem=\"#{code_system_oid(result['codeSystem'])}\" codeSystemName=\"#{result['codeSystem']}\"/>"
          elsif result['unit']
            return "<value xsi:type=\"PQ\" value=\"#{result['value']}\" unit=\"#{result['unit']}\"/>"
          end
          "<value xsi:type=\"CD\" nullFlavor=\"UNK\"/>"
        end

      end
    end
  end
end
