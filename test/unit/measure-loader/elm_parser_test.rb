require 'test_helper'

class ElmParserTest < Minitest::Test

  def setup
    @fixtures_path = File.join('test', 'fixtures', 'measureloading', 'elm_xmls')
  end

  def test_parsing_annotations
    doc = Nokogiri::XML(File.read(File.join(@fixtures_path, 'OpioidMedicationLogic.xml'))) { |config| config.noblanks }
    annotations = Measures::ElmParser.parse(doc)
    expected = JSON.parse(File.read(File.join(@fixtures_path,'OpioidMedicationLogic_Annotations.json')))
    assert_equal expected.deep_symbolize_keys, annotations.deep_symbolize_keys

    doc = Nokogiri::XML(File.read(File.join(@fixtures_path, 'AntithromboticTherapyByEndofHospitalDay2.xml'))) { |config| config.noblanks }
    annotations = Measures::ElmParser.parse(doc)
    expected = JSON.parse(File.read(File.join(@fixtures_path,'AntithromboticTherapyByEndofHospitalDay2_Annotations.json')))
    assert_equal expected.deep_symbolize_keys, annotations.deep_symbolize_keys
  end

  def test_parse_node
    xml =
      '<a r="1">
        <a>define &quot;SDE Ethnicity&quot;:</a>
        <a r="2">
          <a>Patient Characteristic</a>
        </a>
      </a>'
    doc = Nokogiri::XML(xml) { |config| config.noblanks }
    ret = Measures::ElmParser.parse_node(doc, {})
    expected_ret =
      {
        children:
        [
          {
            children: [
              {
                children: [{text: 'define "SDE Ethnicity":'}]
              },
              {
                children: [{children: [{text: "Patient Characteristic"}]}],
                ref_id: "2"
              }
            ],
            ref_id: "1"
          }
        ]
      }
    assert_equal expected_ret, ret
  end

  def test_generate_type_map
    xml =
      '<library xmlns="urn:hl7-org:elm:r1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <expression localId="1" xsi:type="Retrieve"/>
        <expression xsi:type="Retrieve"/>
        <operand  localId="2" xsi:type="AliasRef">
          <suchThat localId="3" xsi:type="In"/>
          <suchThat localId="2"/>
        <operand>
      </library>'
    doc = Nokogiri::XML(xml) { |config| config.noblanks }
    type_map = Measures::ElmParser.generate_localid_to_type_map(doc)
    assert_equal({"1"=>"Retrieve", "2"=>"AliasRef", "3"=>"In"}, type_map)
  end
end
