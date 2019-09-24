module QRDA
  module Cat1
    class MedicationOrderImporter < MedicationImporter
      def initialize(entry_finder = QRDA::Cat1::EntryFinder.new("./cda:entry/cda:substanceAdministration[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.47']"))
        super(entry_finder)
        @reason_xpath = "./cda:entryRelationship[@typeCode='RSON']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.88']/cda:value"
        @entry_class = QDM::MedicationOrder
      end

      def create_entry(entry_element, nrh = NarrativeReferenceHandler.new)
        medication_order = super
        medication_order.reason = extract_reason(entry_element)
        medication_order
      end

    end
  end
end