require 'test_helper'
require 'vcr_setup.rb'
require 'util/vsac_api.rb'

# Tests that ensure VSAC authentication related situations are handled
class VSACAPIAuthTest < Minitest::Test

  def test_valid_username_and_password_provided_does_not_raise
    VCR.use_cassette("vsac_auth_good_credentials") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      assert api.ticket_granting_ticket
      assert api.ticket_granting_ticket[:ticket]
      assert api.ticket_granting_ticket[:expires]
    end
  end

  def test_invalid_username_and_password_provided
    VCR.use_cassette("vsac_auth_bad_credentials") do
      assert_raises Util::VSAC::VSACInvalidCredentialsError do
        api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: 'baduser', password: 'badpass')
        assert api
      end
    end
  end

  def test_empty_username_and_password_provided
    api = nil
    api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: nil, password: nil)

    assert_raises Util::VSAC::VSACNoCredentialsError do
      api.get_valueset('2.16.840.1.113762.1.4.1')
    end
  end

  def test_provided_username_but_no_password
    api = nil
    api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: "vsacuser")

    assert_raises Util::VSAC::VSACNoCredentialsError do
      api.get_valueset('2.16.840.1.113762.1.4.1')
    end
  end

  def test_provided_password_but_no_username
    api = nil
    api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: "vsacuser")

    assert_raises Util::VSAC::VSACNoCredentialsError do
      api.get_valueset('2.16.840.1.113762.1.4.1')
    end
  end

  def test_valid_ticket_granting_ticket_provided_and_used
    VCR.use_cassette("vsac_auth_good_credentials_and_simple_call") do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'],
                                    username: ENV['VSAC_USERNAME'],
                                    password: ENV['VSAC_PASSWORD'])
      assert api.ticket_granting_ticket

      reused_ticket_granting_ticket = {
        ticket: api.ticket_granting_ticket[:ticket],
        expires: api.ticket_granting_ticket[:expires]
      }

      new_api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'],
                                        ticket_granting_ticket: reused_ticket_granting_ticket)
      assert new_api
      valueset = api.get_valueset('2.16.840.1.113762.1.4.1')
      assert valueset
    end
  end

  def test_ticket_granting_ticket_provided_is_missing_or_missing_fields
    assert_raises Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: {})
    end

    missing_ticket = { expires: Time.now + 2.hours }
    assert_raises Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: missing_ticket)
    end

    missing_expires = { ticket: "ImATicketGrantingTicket" }
    assert_raises Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: missing_expires)
    end

    # nil, this shouln't throw an error, It will assume no credentials provided
    Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: nil)
  end

  def test_ticket_granting_ticket_provided_expires_time_has_expired
    assert_raises Util::VSAC::VSACTicketExpiredError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'],
                              ticket_granting_ticket: { ticket: "ImATicketGrantingTicket",
                                                        expires: Time.now - 10.minutes })
    end
  end

  def test_ticket_granting_ticket_provided_ticket_is_bad
    api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'],
                                  ticket_granting_ticket: { ticket: "ImABadTicketGrantingTicket",
                                                            expires: Time.now + 10.minutes })

    VCR.use_cassette("vsac_auth_bad_ticket") do
      assert_raises Util::VSAC::VSACTicketExpiredError do
        api.get_valueset('2.16.840.1.113762.1.4.1')
      end
    end

    # make sure the API has marked the ticket expired
    assert_equal true, api.ticket_granting_ticket[:expires] <= Time.now
  end
end
