module Qrda
  module Export
    module Helper
      module PatientViewHelper
        def provider
          JSON.parse(@provider.to_json) if @provider
        end

        def provider_addresses
          @provider['addresses']
        end

        def provider_street
          self['street'].join('')
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
          @patient.extendedData['medical_record_number']
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
          @patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.55').first.dataElementCodes.first['code']
        end

        def race
          @patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.59').first.dataElementCodes.first['code']
        end

        def ethnic_group
          @patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.56').first.dataElementCodes.first['code']
        end

        def insurance_provider
          @insurance_provider
        end
      end
    end
  end
end
