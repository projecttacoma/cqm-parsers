require 'test_helper'
require 'vcr_setup.rb'
require 'util/vsac_api.rb'

# Tests that ensure VSAC authentication related situations are handled
class VSACAPIAuthTest < Minitest::Test

  def test_valid_apikey_provided_does_not_raise
    VCR.use_cassette("vsac_auth_good_credentials") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: ENV['VSAC_API_KEY'])
      assert api
    end
  end

  def test_empty_api_key_provided
    api = nil
    api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: nil)

    assert_raises Util::VSAC::VSACNoCredentialsError do
      api.get_valueset('2.16.840.1.113762.1.4.1')
    end
  end
end
