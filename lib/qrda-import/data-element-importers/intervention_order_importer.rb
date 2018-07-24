module QRDA
  module Cat1
    class InterventionOrderImporter < SectionImporter
      def initialize(entry_finder = QRDA::Cat1::EntryFinder.new("./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.31']"))
        super(entry_finder)
        @code_xpath = './cda:code'
        @author_datetime_xpath = "./cda:author/cda:time"
        @entry_class = QDM::InterventionOrder
      end

      def create_entry(entry_element, nrh = NarrativeReferenceHandler.new)
        intervention_order = super
        intervention_order
      end

    end
  end
end