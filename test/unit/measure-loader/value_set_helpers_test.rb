require 'test_helper'

class ValueSetHelpersTest < Minitest::Test

  def test_remove_urnoid
    orig_hash = {a: "abc", b: "12urn:oid:3", c: {i: "12urn:oid:3"}, d: [{j: "12urn:oid:3"}], n: nil}
    expected_hash = {a: "abc", b: "123", c: {i: "123"}, d: [{j: "123"}], n: nil}

    Measures::ValueSetHelpers.remove_urnoid(orig_hash)
    assert_equal expected_hash, orig_hash
  end

end