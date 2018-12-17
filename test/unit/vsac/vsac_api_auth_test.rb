require 'test_helper'
require 'vcr_setup.rb'

# Tests that ensure VSAC authentication related situations are handled
class VSACAPIAuthTest < ActiveSupport::TestCase

  test 'valid username and password provided' do
    VCR.use_cassette("vsac_auth_good_credentials") do
      assert_nothing_raised do
        api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
        assert_not_nil api.ticket_granting_ticket
        assert_not_nil api.ticket_granting_ticket[:ticket]
        assert_not_nil api.ticket_granting_ticket[:expires]
      end
    end
  end

  test 'invalid username and password provided' do
    VCR.use_cassette("vsac_auth_bad_credentials") do
      assert_raise Util::VSAC::VSACInvalidCredentialsError do
        api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: 'baduser', password: 'badpass')
      end
    end
  end

  test 'empty username and password provided' do
    api = nil
    assert_nothing_raised do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: nil, password: nil)
    end

    # now attempt to get a valueset
    assert_raise Util::VSAC::VSACNoCredentialsError do
      api.get_valueset('2.16.840.1.113762.1.4.1')
    end
  end

  test 'provided username but no password' do
    api = nil
    assert_nothing_raised do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: "vsacuser")
    end

    # now attempt to get a valueset
    assert_raise Util::VSAC::VSACNoCredentialsError do
      api.get_valueset('2.16.840.1.113762.1.4.1')
    end
  end

  test 'provided password but no username' do
    api = nil
    assert_nothing_raised do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: "vsacuser")
    end

    # now attempt to get a valueset
    assert_raise Util::VSAC::VSACNoCredentialsError do
      api.get_valueset('2.16.840.1.113762.1.4.1')
    end
  end

  test 'valid ticket_granting_ticket provided and used' do
    VCR.use_cassette("vsac_auth_good_credentials_and_simple_call") do
      # first get a ticket_granting_ticket
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: ENV['VSAC_USERNAME'], password: ENV['VSAC_PASSWORD'])
      assert_not_nil api.ticket_granting_ticket

      reused_ticket_granting_ticket = {
        ticket: api.ticket_granting_ticket[:ticket],
        expires: api.ticket_granting_ticket[:expires]
      }

      newApi = nil
      # ensure that nothing is raised when constucting api using reused tgt
      assert_nothing_raised do
        newApi = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: reused_ticket_granting_ticket)
        valueset = api.get_valueset('2.16.840.1.113762.1.4.1')
        assert_not_nil valueset
      end
    end
  end

  test 'ticket_granting_ticket provided is missing or missing fields' do
    # empty object
    assert_raise Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: {})
    end

    # missing ticket
    assert_raise Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: { expires: Time.now + 2.hours })
    end

    # missing expires
    assert_raise Util::VSAC::VSACArgumentError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: { ticket: "ImATicketGrantingTicket" })
    end

    # nil, this shouln't throw an error, It will assume no credentials provided
    assert_nothing_raised do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: nil)
    end
  end

  test 'ticket_granting_ticket provided expires time has expired' do
    assert_raise Util::VSAC::VSACTicketExpiredError do
      Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'],
        ticket_granting_ticket: { ticket: "ImATicketGrantingTicket", expires: Time.now - 10.minutes })
    end
  end

  test 'ticket_granting_ticket provided ticket is bad' do
    api = nil
    assert_nothing_raised do
      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'],
        ticket_granting_ticket: { ticket: "ImABadTicketGrantingTicket", expires: Time.now + 10.minutes })
    end

    # attempt to get something with the bad ticket
    VCR.use_cassette("vsac_auth_bad_ticket") do
      assert_raise Util::VSAC::VSACTicketExpiredError do
        api.get_valueset('2.16.840.1.113762.1.4.1')
      end
    end

    # make sure the API has marked the ticket expired
    assert_equal true, api.ticket_granting_ticket[:expires] <= Time.now
  end
end
