require 'test_helper'
require 'vcr_setup.rb'

class VSACApiTest < ActiveSupport::TestCase
  test 'api with insufficent config' do
    assert_raise Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: {})
    end

    assert_raise Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: nil)
    end

    assert_raise Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: { auth_url: "hi.com", content_url: "there"})
    end
  end

  test 'get_valueset with version' do
    VCR.use_cassette("vsac_vs_version") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      vs = api.get_valueset("2.16.840.1.113883.3.600.1.1834", version: "MU2 EP Update 2014-07-01")
      assert_not_nil vs
      doc = Nokogiri::XML(vs)
      assert_equal 148, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

  test 'get_valuest with include_draft no profile' do
    VCR.use_cassette("vsac_vs_include_draft_no_profile") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      assert_raise Util::VSAC::VSACArgumentError do
        api.get_valueset("2.16.840.1.113883.3.600.1.1834", include_draft: true)
      end
    end
  end

  test 'get_valueset with include_draft specified profile' do
    VCR.use_cassette("vsac_vs_include_draft_with_profile") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      vs = api.get_valueset("2.16.840.1.113762.1.4.1", include_draft: true, profile: "eCQM Update 2018-05-04")
      assert_not_nil vs
      doc = Nokogiri::XML(vs)
      assert_equal 2, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

  test 'get_valueset no options' do
    VCR.use_cassette("vsac_vs_no_options") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      vs = api.get_valueset("2.16.840.1.113762.1.4.1")
      assert_not_nil vs
      doc = Nokogiri::XML(vs)
      assert_equal 2, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

  test 'get_valueset not found' do
    VCR.use_cassette("vsac_vs_not_found") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      assert_raise Util::VSAC::VSNotFoundError do
        api.get_valueset("bad.oid")
      end
    end
  end

  test 'get_valueset with release' do
    VCR.use_cassette("vsac_vs_release") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      vs = api.get_valueset("2.16.840.1.113762.1.4.1", release: "MU2 EP Update 2014-05-30")
      assert_not_nil vs
      doc = Nokogiri::XML(vs)
      assert_equal 3, doc.xpath("ns0:RetrieveMultipleValueSetsResponse/ns0:DescribedValueSet/ns0:ConceptList/ns0:Concept").count
    end
  end

end
