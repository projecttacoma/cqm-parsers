module QRDA
  module Cat1

    # This class is the central location for taking a QRDA Cat 1 XML document and converting it
    # into the processed form we store in MongoDB. The class does this by running each measure
    # independently on the XML document
    #
    # This class is a Singleton. It should be accessed by calling PatientImporter.instance
    class PatientImporter
      include Singleton
      include DemographicsImporter

      def initialize
        # This differs from other HDS patient importers in that sections can have multiple importers
        @data_element_importers = []

        @data_element_importers << generate_importer(EncounterPerformedImporter)
        @data_element_importers << generate_importer(PhysicalExamPerformedImporter)
        @data_element_importers << generate_importer(LaboratoryTestPerformedImporter)
        @data_element_importers << generate_importer(DiagnosisImporter)
        @data_element_importers << generate_importer(InterventionOrderImporter)
        @data_element_importers << generate_importer(ProcedurePerformedImporter)
        @data_element_importers << generate_importer(MedicationActiveImporter)
        @data_element_importers << generate_importer(AllergyIntoleranceImporter)
        @data_element_importers << generate_importer(MedicationOrderImporter)
        @data_element_importers << generate_importer(DiagnosticStudyOrderImporter)

        @data_element_importers << generate_importer(AdverseEventImporter)
        @data_element_importers << generate_importer(AssessmentPerformedImporter)
        @data_element_importers << generate_importer(CommunicationFromPatientToProviderImporter)
        @data_element_importers << generate_importer(CommunicationFromProviderToPatientImporter)
        @data_element_importers << generate_importer(CommunicationFromProviderToProviderImporter)
        @data_element_importers << generate_importer(DeviceAppliedImporter)
        @data_element_importers << generate_importer(DeviceOrderImporter)
        @data_element_importers << generate_importer(DiagnosticStudyPerformedImporter)
        @data_element_importers << generate_importer(EncounterOrderImporter)
        @data_element_importers << generate_importer(ImmunizationAdministeredImporter)
        @data_element_importers << generate_importer(InterventionPerformedImporter)
        @data_element_importers << generate_importer(LaboratoryTestOrderImporter)
        @data_element_importers << generate_importer(MedicationAdministeredImporter)
        @data_element_importers << generate_importer(MedicationDischargeImporter)
        @data_element_importers << generate_importer(MedicationDispensedImporter)
        @data_element_importers << generate_importer(ProcedureOrderImporter)
        @data_element_importers << generate_importer(SubstanceAdministeredImporter)
        
        #                                    generate_importer(ProcedurePerformedImporter, "./cda:entry/cda:procedure[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.64']", '2.16.840.1.113883.3.560.1.6'),
        #@data_element_importer << generate_importer(EncounterOrderImporter, '2.16.840.1.113883.3.560.1.83')
        # @section_importers[:adverse_events] = [generate_importer(AdverseEventImporter, nil, '2.16.840.1.113883.10.20.28.3.120')] #adverse event
        # @section_importers[:assessments] = [generate_importer(CDA::ProcedureImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.144']", '2.16.840.1.113883.10.20.28.3.117')] #assessment performed
        # @section_importers[:care_goals] = [generate_importer(CDA::SectionImporter, "./cda:entry/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.1']", '2.16.840.1.113883.3.560.1.9')] #care goal
        
        # @section_importers[:conditions] = [generate_importer(GestationalAgeImporter, nil, '2.16.840.1.113883.3.560.1.1001'),
        #                                    generate_importer(EcogStatusImporter, nil, '2.16.840.1.113883.3.560.1.1001'),
        #                                    generate_importer(SymptomActiveImporter, nil, '2.16.840.1.113883.3.560.1.69', 'active'),
        #                                    generate_importer(DiagnosisActiveImporter, nil, '2.16.840.1.113883.3.560.1.2', 'active'),
        
        #                                    generate_importer(CDA::ConditionImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.54']", '2.16.840.1.113883.3.560.1.404'), # patient characteristic age
        #                                    generate_importer(CDA::ConditionImporter, "//cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.14']", '2.16.840.1.113883.3.560.1.24', 'resolved'), #diagnosis resolved
        #                                    generate_importer(DiagnosisInactiveImporter, nil, '2.16.840.1.113883.3.560.1.23', 'inactive'), #diagnosis inactive
        #                                    generate_importer(ClinicalTrialParticipantImporter, nil, '2.16.840.1.113883.3.560.1.401')]

        
        # @section_importers[:medications] = [generate_importer(CDA::MedicationImporter, "./cda:entry/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.105']/cda:entryRelationship/cda:substanceAdministration[cda:templateId/@root='2.16.840.1.113883.10.20.22.4.16']", '2.16.840.1.113883.3.560.1.199', 'discharge'), #discharge medication activity
        #                                     generate_importer(MedicationActiveImporter, nil, '2.16.840.1.113883.3.560.1.13', 'active'), #medication active
        #                                     generate_importer(MedicationSubstanceAdministeredImporter, nil, ['2.16.840.1.113883.3.560.1.64','2.16.840.1.113883.3.560.1.14'], 'administered'), #substance administered
        #                                     generate_importer(CDA::MedicationImporter, "./cda:entry/cda:substanceAdministration[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.47']", '2.16.840.1.113883.3.560.1.17', 'ordered'), #medication order TODO: ADD NEGATON REASON HANDLING SOMEHOW
        #                                     generate_importer(MedicationDispensedImporter, nil, '2.16.840.1.113883.3.560.1.8', 'dispensed'),
        #                                     generate_importer(MedicationDispensedActImporter, nil, '2.16.840.1.113883.3.560.1.8', 'dispensed'),
        #                                     generate_importer(ImmunizationAdministeredImporter, nil, '2.16.840.1.113883.10.20.28.3.112', 'administered')] #immunization
        # @section_importers[:communications] = [generate_importer(CDA::CommunicationImporter, "./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.3']", '2.16.840.1.113883.3.560.1.31'), #comm from provider to patient
        #                                        generate_importer(CDA::CommunicationImporter, "./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.2']", '2.16.840.1.113883.3.560.1.30'), #comm from patient to provider
        #                                        generate_importer(CDA::CommunicationImporter, "./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.4']", '2.16.840.1.113883.3.560.1.29')] #comm from provider to provider, not done
        
        #                                    generate_importer(CDA::ProcedureImporter, "./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.32']", '2.16.840.1.113883.3.560.1.46', 'performed'), #intervention performed
        #                                    generate_importer(CDA::ProcedureImporter, "./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.34']", '2.16.840.1.113883.3.560.1.47'), #intervention result
        #                                    generate_importer(ProcedureOrderImporter, nil, '2.16.840.1.113883.3.560.1.62', 'ordered'),
        
        #                                    generate_importer(CDA::ProcedureImporter, "./cda:entry/cda:procedure[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.66']", '2.16.840.1.113883.3.560.1.63'),
        #                                    generate_importer(CDA::ProcedureImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.69']", '2.16.840.1.113883.3.560.1.21'), #risk category assessment
        #                                    generate_importer(CDA::ProcedureImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.18']", '2.16.840.1.113883.3.560.1.3', 'performed'), #diagnostic study performed
        #                                    generate_importer(CDA::ProcedureImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.20']", '2.16.840.1.113883.3.560.1.11'), #diagnostic study result
        #                                    generate_importer(DiagnosticStudyOrderImporter, nil, '2.16.840.1.113883.3.560.1.40', 'ordered')]

        # @section_importers[:allergies] = [generate_importer(AllergyIntoleranceImporter, nil, '2.16.840.1.113883.10.20.28.3.119'),
        #                                   generate_importer(ProcedureIntoleranceImporter, nil, '2.16.840.1.113883.3.560.1.61'),
        #                                   generate_importer(CDA::AllergyImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.46']", '2.16.840.1.113883.3.560.1.67'), #medication intolerance
        #                                   generate_importer(CDA::AllergyImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.43']", '2.16.840.1.113883.3.560.1.7'), #medication adverse effect
        #                                   generate_importer(CDA::AllergyImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.44']", '2.16.840.1.113883.3.560.1.1')] #medication allergy

        # @section_importers[:medical_equipment] = [generate_importer(CDA::MedicalEquipmentImporter, "./cda:entry/cda:procedure[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.7']", '2.16.840.1.113883.3.560.1.10', 'applied'),
        #                                           generate_importer(CDA::MedicalEquipmentImporter, "./cda:entry/cda:act[cda:code/@code = 'SPLY']", '2.16.840.1.113883.3.560.1.137'),
        #                                           generate_importer(DeviceOrderImporter, nil, '2.16.840.1.113883.3.560.1.37', 'ordered')]

        # @section_importers[:results] = [generate_importer(LabOrderImporter, nil, '2.16.840.1.113883.3.560.1.50', 'ordered'), #lab ordered
        #                                 generate_importer(CDA::ResultImporter, "./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.34']", '2.16.840.1.113883.3.560.1.47'), #intervention result
        #                                 generate_importer(CDA::ResultImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.57']", '2.16.840.1.113883.3.560.1.18'), #physical exam finding
        #                                 generate_importer(CDA::ResultImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.28']", '2.16.840.1.113883.3.560.1.88'), #functional status result  
        #                                 generate_importer(CDA::ResultImporter, "./cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.26']", '2.16.840.1.113883.3.560.1.85'),  #functional status, performed
        #                                 generate_importer(LabResultImporter, nil, '2.16.840.1.113883.3.560.1.12')] #lab result


        # @section_importers[:social_history] = [generate_importer(TobaccoUseImporter, nil, '2.16.840.1.113883.3.560.1.1001', 'completed')]

        # @section_importers[:insurance_providers] = [generate_importer(InsuranceProviderImporter, nil, '2.16.840.1.113883.3.560.1.405')]

      end 

      def parse_cat1(doc)
        patient = Patient.new
        entry_id_map = {}
        #HealthDataStandards::Import::C32::PatientImporter.instance.get_demographics(patient, doc)
        import_data_elements(patient, doc, entry_id_map)
        #get_patient_expired(patient, doc)
        #record.dedup_record!
        normalize_references(patient, entry_id_map)
        get_demographics(patient, doc)
        patient
      end

      def import_data_elements(patient, doc, entry_id_map)
        context = doc.xpath("/cda:ClinicalDocument/cda:component/cda:structuredBody/cda:component/cda:section[cda:templateId/@root = '2.16.840.1.113883.10.20.24.2.1']")
        nrh = NarrativeReferenceHandler.new
        nrh.build_id_map(doc)
        @data_element_importers.each do |entry_package|
          data_elements, id_map = entry_package.package_entries(context, nrh)
          new_data_elements = []

          id_map.each_value do |elem_ids|
            
            elem_id = elem_ids.first
            data_element = data_elements.find { |de| de.id == elem_id }

            elem_ids[1,elem_ids.length].each do |merge_id|
              merge_element = data_elements.find { |de| de.id == merge_id }
              data_element.merge!(merge_element)
            end

            new_data_elements << data_element
          end

          patient.dataElements << new_data_elements
          entry_id_map.merge!(id_map)
        end
      end

      def get_patient_expired(record, doc)
        entry_elements = doc.xpath("/cda:ClinicalDocument/cda:component/cda:structuredBody/cda:component/cda:section[cda:templateId/@root = '2.16.840.1.113883.10.20.24.2.1']/cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.54']")
        if !entry_elements.empty?
          record.expired = true
          record.deathdate = HealthDataStandards::Util::HL7Helper.timestamp_to_integer(entry_elements.at_xpath("./cda:effectiveTime/cda:low")['value'])
        end
      end

      def normalize_references(patient, entry_id_map)
        patient.dataElements.each do |data_element|
          if data_element.respond_to?(:relatedTo) && data_element.relatedTo
            data_element.relatedTo.map! { |related_to| entry_id_map[related_to] }
          end
        end
      end

      private

      def generate_importer(importer_class)
        importer = EntryPackage.new(importer_class.new)
      end
    end
  end
end
