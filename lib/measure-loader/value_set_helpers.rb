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
                fhirId: code_hash
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

      def code_systems_by_name()
        # TODO: re-consider this approach after Visac API is migrated to FHIR API
        # At the moment we have to guess system's URI by Code system name or Value Set name
        # (it can be named slightly different than the original code system name)
        # Important : UI will also create a reverse Map from it URI -> name. The last name wins, so the order of elements is important
        return {
            'medication-admin-status' => 'http://terminology.hl7.org/CodeSystem/medication-admin-status',
            'medication-statement-status' => 'http://hl7.org/fhir/CodeSystem/medication-statement-status',
            'medicationrequest-intent' => 'http://hl7.org/fhir/CodeSystem/medicationrequest-intent',
            'medicationrequest-status' => 'http://hl7.org/fhir/CodeSystem/medicationrequest-status',
            'discharge-disposition' => 'http://terminology.hl7.org/CodeSystem/discharge-disposition',
            'encounter-status' => 'http://hl7.org/fhir/encounter-status',
            'event-status' => 'http://hl7.org/fhir/event-status',
            'condition-ver-status' => 'http://terminology.hl7.org/CodeSystem/condition-ver-status',
            'ConditionVerificationStatusCodes' => 'http://terminology.hl7.org/CodeSystem/condition-ver-status',
            'ConditionVerificationStatus' => 'http://terminology.hl7.org/CodeSystem/condition-ver-status',
            'condition-clinical' => 'http://terminology.hl7.org/CodeSystem/condition-clinical',
            'ConditionClinicalStatusCodes' => 'http://terminology.hl7.org/CodeSystem/condition-clinical',
            'ConditionClinicalStatus' => 'http://terminology.hl7.org/CodeSystem/condition-clinical',
            'AllergyIntoleranceClinicalStatusCodes' => 'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical',
            'allergyintolerance-clinical' => 'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical',
            'allergyintolerance-verification' => 'http://terminology.hl7.org/CodeSystem/allergyintolerance-verification',
            'AllergyIntoleranceVerificationStatusCodes' => 'http://terminology.hl7.org/CodeSystem/allergyintolerance-verification',
            'ConditionCategoryCodes' => 'http://terminology.hl7.org/CodeSystem/condition-category',
            'USCoreConditionCategoryExtensionCodes' => 'http://hl7.org/fhir/us/core/CodeSystem/condition-category',
            'request-status' => 'http://hl7.org/fhir/request-status',
            'request-intent' => 'http://hl7.org/fhir/request-intent',
            'admit-source' => 'http://terminology.hl7.org/CodeSystem/admit-source',
            'ActCode' => 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
            'ReasonMedicationGivenCodes' => 'http://terminology.hl7.org/CodeSystem/reason-medication-given',
            'MedicationRequestCategoryCodes' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-category',
            'MedicationRequestCategory' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-category',
            'GTSAbbreviation' => 'http://terminology.hl7.org/CodeSystem/v3-GTSAbbreviation',
            'MedicationRequest Status Reason Codes' => 'http://terminology.hl7.org/CodeSystem/medicationrequest-status-reason',
            'DiagnosticReportStatus' => 'http://hl7.org/fhir/diagnostic-report-status',
            'ObservationCategoryCodes' => 'http://terminology.hl7.org/CodeSystem/observation-category',
            'LOINCCodes' => 'http://loinc.org',
            # Source: https://www.hl7.org/fhir/terminologies-systems.html#tabs-ext & https://cts.nlm.nih.gov/fhir/index.html
            'LOINC' => 'http://loinc.org',
            'SNOMED CT' => 'http://snomed.info/sct',
            'SNOMEDCT:2017-09' => 'http://snomed.info/sct',
            'SNOMEDCT' => 'http://snomed.info/sct',
            'CPT' => 'http://www.ama-assn.org/go/cpt',
            # Source: https://cts.nlm.nih.gov/fhir/index.html
            'SOP' => 'http://www.nlm.nih.gov/research/umls/sop',
            'ICD9CM' => 'http://hl7.org/fhir/sid/icd-9-cm',
            'ICD10PCS' => 'http://www.icd10data.com/icd10pcs',
            'ICD10CM' => 'http://hl7.org/fhir/sid/icd-10-cm',
            'ActMood' => 'http://hl7.org/fhir/v3/ActMood',
            'ActPriority' => 'http://hl7.org/fhir/v3/ActPriority',
            'ActReason' => 'http://hl7.org/fhir/v3/ActReason',
            'ActRelationshipType' => 'http://hl7.org/fhir/v3/ActRelationshipType',
            'ActStatus' => 'http://hl7.org/fhir/v3/ActStatus',
            'AddressUse' => 'http://hl7.org/fhir/v3/AddressUse',
            'AdministrativeGender' => 'http://hl7.org/fhir/v3/AdministrativeGender',
            'AdministrativeSex' => 'http://hl7.org/fhir/v2/0001',
            'CDT' => 'http://www.nlm.nih.gov/research/umls/cdt',
            'CVX' => 'http://hl7.org/fhir/sid/cvx',
            'Confidentiality' => 'http://hl7.org/fhir/v3/Confidentiality',
            'DischargeDisposition' => 'http://hl7.org/fhir/v2/0112',
            'EntityNamePartQualifier' => 'http://hl7.org/fhir/v3/EntityNamePartQualifier',
            'EntityNameUse' => 'http://hl7.org/fhir/v3/EntityNameUse',
            'LanguageAbilityMode' => 'http://hl7.org/fhir/v3/LanguageAbilityMode',
            'LanguageAbilityProficiency' => 'http://hl7.org/fhir/v3/LanguageAbilityProficiency',
            'LivingArrangement' => 'http://hl7.org/fhir/v3/LivingArrangement',
            'MaritalStatus' => 'http://hl7.org/fhir/v3/MaritalStatus',
            'MED-RT' => 'http://www.nlm.nih.gov/research/umls/MED-RT',
            'NCI' => 'http://ncimeta.nci.nih.gov',
            'NDFRT' => 'http://hl7.org/fhir/ndfrt',
            'NUCCPT' => 'http://nucc.org/provider-taxonomy',
            'NullFlavor' => 'http://hl7.org/fhir/v3/NullFlavor',
            'ObservationInterpretation' => 'http://hl7.org/fhir/v3/ObservationInterpretation',
            'ObservationValue' => 'http://hl7.org/fhir/v3/ObservationValue',
            'ParticipationFunction' => 'http://hl7.org/fhir/v3/ParticipationFunction',
            'ParticipationMode' => 'http://hl7.org/fhir/v3/ParticipationMode',
            'ParticipationType' => 'http://hl7.org/fhir/v3/ParticipationType',
            'RXNORM' => 'http://www.nlm.nih.gov/research/umls/rxnorm',
            'ReligiousAffiliation' => 'http://hl7.org/fhir/v3/ReligiousAffiliation',
            'RoleClass' => 'http://hl7.org/fhir/v3/RoleClass',
            'RoleCode' => 'http://hl7.org/fhir/v3/RoleCode',
            'RoleStatus' => 'http://hl7.org/fhir/v3/RoleStatus',
            'SOP' => 'http://www.nlm.nih.gov/research/umls/sop',
            'UCUM' => 'http://unitsofmeasure.org',
            'UMLS' => 'http://www.nlm.nih.gov/research/umls',
            'UNII' => 'http://fdasis.nlm.nih.gov',
            'mediaType' => 'http://hl7.org/fhir/v3/MediaType',
            'Diagnosis Role' => 'http://terminology.hl7.org/CodeSystem/diagnosis-role',
            'DiagnosisRole' => 'http://terminology.hl7.org/CodeSystem/diagnosis-role',
            'CDCREC' => 'http://cts.nlm.nih.gov/fhir/cs/cdcrec',
            'HCPCSReleaseCodeSets' => 'http://www.cms.gov/Medicare/Coding/HCPCSReleaseCodeSets',
            'HCPCS' => 'http://www.cms.gov/Medicare/Coding/HCPCSReleaseCodeSets',
            'v3.GTSAbbreviation' => 'http://terminology.hl7.org/ValueSet/v3-GTSAbbreviation',
            'EventTiming' => 'http://hl7.org/fhir/event-timing',
            'v3.TimingEvent' => 'http://terminology.hl7.org/CodeSystem/v3-TimingEvent',
            'TimingEvent' => 'http://terminology.hl7.org/CodeSystem/v3-TimingEvent',
            'DaysOfWeek' => 'http://hl7.org/fhir/days-of-week'
        }
      end
    end
  end
end
