require 'test_helper'
require 'vcr_setup.rb'

class ValueSetHelpersTest < Minitest::Test

  def test_remove_urnoid
    orig_hash = {a: "abc", b: "12urn:oid:3", c: {i: "12urn:oid:3"}, d: [{j: "12urn:oid:3"}], n: nil}
    expected_hash = {a: "abc", b: "123", c: {i: "123"}, d: [{j: "123"}], n: nil}

    Measures::ValueSetHelpers.remove_urnoid(orig_hash)
    assert_equal expected_hash, orig_hash
  end

  def test_code_systems
    VCR.use_cassette('gs_code_systems_mappings', {match_requests_on: [:method, :uri_no_st]}) do
      code_systems = Measures::ValueSetHelpers.code_systems_mappings
      assert code_systems != nil
      assert_equal 87, code_systems['by_name'].keys.size
      assert_equal 87, code_systems['by_name'].values.size
      assert_equal 81, code_systems['by_oid'].keys.size
      assert_equal 81, code_systems['by_oid'].values.size
      assert_equal 'http://snomed.info/sct', code_systems['by_oid']['2.16.840.1.113883.6.96']
      assert_nil code_systems['by_oid']['WRONG_OID']
      assert_equal 'http://snomed.info/sct', code_systems['by_name']['SNOMEDCT']
      assert_nil code_systems['by_name']['WRONG_NAME']
    end
  end

end
