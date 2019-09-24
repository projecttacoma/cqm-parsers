module QRDA
  module Cat1
    class ImmunizationAdministeredImporter < MedicationImporter
      def initialize(entry_finder = QRDA::Cat1::EntryFinder.new("./cda:entry/cda:substanceAdministration[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.140']"))
        super(entry_finder)
        @relevant_period_xpath = nil
        @author_datetime_xpath = "./cda:effectiveTime"
        @reason_xpath = "./cda:entryRelationship[@typeCode='RSON']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.88']/cda:value"
        @entry_class = QDM::ImmunizationAdministered
      end

      def create_entry(entry_element, nrh = NarrativeReferenceHandler.new)
        immunization_administered = super
        immunization_administered.reason = extract_reason(entry_element)
        immunization_administered
      end

    end
  end
end