require_relative '../../test_helper'
require 'cqm/models'

module QRDA
  module Cat1
    class PatientImporterTest < MiniTest::Test
      def setup
        @importer = Cat1::PatientImporter.instance
        @patient = QDM::Patient.new
        @map = {}
      end

      # Test that duplicate entries are combined using ids
      def test_patient_dedup
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/0_1 N_GP Adult 2.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        @importer.import_data_elements(@patient, doc, @map)
        
        # There are 4 entry elements in the uploaded QRDA file
        # 2 entries are combined since the share the same id (root and extension)
        # 1 entry has a common root (1.3.6.1.4.1.115), and a unique extension (5ada27b7aeac50e2db23159f)
        # 1 entry has a common extension (5ada27b7aeac50e2db23159f), and a unique root (1.3.6.1.4.1.116)
        assert_equal 3, @patient.dataElements.length
        de = @patient.dataElements.first
        assert_equal 2, de.dataElementCodes.length
        assert_operator de.dataElementCodes[0], :!=, de.dataElementCodes[1]
      end

      # Test that a low value can be null flavored
      def test_low_time_import
        patient1 = QDM::Patient.new
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/single_entry.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        @importer.import_data_elements(patient1, doc, @map)

        assert_equal 1, patient1.dataElements.length
        de = patient1.dataElements.first
        # Low value is nullFlavored
        assert_equal nil, de.relevantPeriod.low

        low = doc.at_css('templateId[root="2.16.840.1.113883.10.20.24.3.38"] ~ effectiveTime low')
        # Remove nullFavor
        low.attributes['nullFlavor'].remove
        # Add time value
        low.set_attribute('value', '20120709081500')
        patient2 = QDM::Patient.new
        @importer.import_data_elements(patient2, doc, @map)

        assert_equal 1, patient2.dataElements.length
        de = patient2.dataElements.first
        assert_equal 2012, de.relevantPeriod.low.year
      end

      # Test that result values are imported with decimal precision
      def test_result_value_import
        patient1 = QDM::Patient.new
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/single_entry.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        @importer.import_data_elements(patient1, doc, @map)

        assert_equal 1, patient1.dataElements.length
        de = patient1.dataElements.first
        assert_equal 3.4, de.result
      end
    end
  end
end
