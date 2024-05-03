require 'test_helper'
require 'vcr_setup.rb'

class VSACApiTest < Minitest::Test
  def test_api_with_insufficent_config
    assert_raises Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: {})
    end

    assert_raises Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: nil)
    end

    assert_raises Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: { auth_url: "hi.com", content_url: "there"})
    end
  end

  def test_get_valueset_with_version
    VCR.use_cassette("vsac_vs_version") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: ENV['VSAC_API_KEY'])
      vs = api.get_valueset("2.16.840.1.113883.3.600.1.1834", version: "MU2 EP Update 2014-07-01")
      assert vs
      doc = Nokogiri::XML(vs)
      assert_equal 148, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

  def test_get_valuest_with_include_draft_no_profile
    VCR.use_cassette("vsac_vs_include_draft_no_profile") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: ENV['VSAC_API_KEY'])
      assert_raises Util::VSAC::VSACArgumentError do
        api.get_valueset("2.16.840.1.113883.3.600.1.1834", include_draft: true)
      end
    end
  end

  def test_get_valueset_with_include_draft_specified_profile
    VCR.use_cassette("vsac_vs_include_draft_with_profile") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: ENV['VSAC_API_KEY'])
      vs = api.get_valueset("2.16.840.1.113762.1.4.1", include_draft: true, profile: "eCQM Update 2019-05-10")
      assert vs
      doc = Nokogiri::XML(vs)
      assert_equal 2, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

  def test_get_valueset_no_options
    VCR.use_cassette("vsac_vs_no_options") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: ENV['VSAC_API_KEY'])
      vs = api.get_valueset("2.16.840.1.113762.1.4.1")
      assert vs
      doc = Nokogiri::XML(vs)
      assert_equal 2, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

  def test_get_valueset_not_found
    VCR.use_cassette("vsac_vs_not_found") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: ENV['VSAC_API_KEY'])
      assert_raises Util::VSAC::VSNotFoundError do
        api.get_valueset("bad.oid")
      end
    end
  end

  def test_get_valueset_with_release
    VCR.use_cassette("vsac_vs_release") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: ENV['VSAC_API_KEY'])
      vs = api.get_valueset("2.16.840.1.113762.1.4.1", release: "MU2 EP Update 2014-05-30")
      assert vs
      doc = Nokogiri::XML(vs)
      assert_equal 3, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

end
