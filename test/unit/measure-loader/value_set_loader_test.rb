require 'test_helper'
require 'vcr_setup.rb'

class ValueSetLoaderTest < Minitest::Test

  def setup
    @vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
  end

  def test_can_use_cache
    VCR.use_cassette('measure__test_can_use_cache') do
      vs_loader = Measures::ValueSetLoader.new(@vsac_options, get_ticket_granting_ticket)
      needed_value_sets = [{oid: "2.16.840.1.113883.3.117.1.7.1.292", version: nil, profile: nil}]

      valuesets = vs_loader.retrieve_and_modelize_value_sets_from_vsac(needed_value_sets)

      stub_request(:any, /\./).to_timeout # disable all network connections
      valuesets_again = vs_loader.retrieve_and_modelize_value_sets_from_vsac(needed_value_sets)
      WebMock.reset!

      assert_equal(valuesets, valuesets_again)
    end
  end

end