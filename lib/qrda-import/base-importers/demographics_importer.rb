module QRDA
  module Cat1
    module DemographicsImporter
      def get_demographics(patient, doc)
        # effective_date = doc.at_xpath('/cda:ClinicalDocument/cda:effectiveTime')['value']
        # patient.effective_time = HL7Helper.timestamp_to_integer(effective_date)
        patient_role_element = doc.at_xpath('/cda:ClinicalDocument/cda:recordTarget/cda:patientRole')
        patient_element = patient_role_element.at_xpath('./cda:patient')
        # patient.title = patient_element.at_xpath('cda:name/cda:title').try(:text)
        patient.givenNames = [patient_element.at_xpath('cda:name/cda:given').text]
        patient.familyName = patient_element.at_xpath('cda:name/cda:family').text
        patient.birthDatetime = Time.parse(patient_element.at_xpath('cda:birthTime')['value']).utc
        pcbd = QDM::PatientCharacteristicBirthdate.new
        pcbd.birthDatetime = patient.birthDatetime
        pcbd.dataElementCodes = [{ code: '21112-8', codeSystem: 'LOINC' }]
        patient.dataElements << pcbd

        pcs = QDM::PatientCharacteristicSex.new
        gender_code = patient_element.at_xpath('cda:administrativeGenderCode')['code']
        pcs.dataElementCodes = [{ code: gender_code, codeSystem: 'AdministrativeGender' }]
        patient.dataElements << pcs

        # TODO: Investigate what of this HDS import codes needs to be addressed in this qrda parser.
        # gender_node = patient_element.at_xpath('cda:administrativeGenderCode')
        # patient.gender = gender_node['code']
        # id_node = patient_role_element.at_xpath('./cda:id')
        # patient.medical_record_number = id_node['extension']
        
        # parse race, ethnicity, and spoken language
        # race_node = patient_element.at_xpath('cda:raceCode')
        # patient.race = { 'code' => race_node['code'], 'codeSystem' => 'CDC Race' } if race_node
        # ethnicity_node = patient_element.at_xpath('cda:ethnicGroupCode')
        # patient.ethnicity = {'code' => ethnicity_node['code'], 'codeSystem' => 'CDC Race'} if ethnicity_node
        # marital_status_node = patient_element.at_xpath("./cda:maritalStatusCode")
        # patient.marital_status = {code: marital_status_node['code'], code_set: "HL7 Marital Status"} if marital_status_node
        # ra_node = patient_element.at_xpath("./cda:religiousAffiliationCode")
        # patient.religious_affiliation = {code: ra_node['code'], code_set: "Religious Affiliation"} if ra_node
        # languages = patient_element.search('languageCommunication').map {|lc| lc.at_xpath('cda:languageCode')['code'] }
        # patient.languages = languages unless languages.empty?
        
        # patient.addresses = patient_role_element.xpath("./cda:addr").map { |addr| import_address(addr) }
        # patient.telecoms = patient_role_element.xpath("./cda:telecom").map { |tele| import_telecom(tele) }
        
      end
    end
  end
end
