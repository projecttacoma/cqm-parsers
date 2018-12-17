require 'test_helper'
require 'vcr_setup.rb'

# Tests that ensure VSAC utility functions fetch and parse correct data.
class VSACAPIUtilTest < ActiveSupport::TestCase
  setup do
    @api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'])
  end

  test 'get_profile_names' do
    VCR.use_cassette("vsac_util_get_profiles") do
      expected_profiles = ["Most Recent Code System Versions in VSAC",
        "eCQM Update 2018-05-04",
        "C-CDA R2.1 2018-02-01",
        "CMS 2018 IQR Voluntary Hybrid Reporting",
        "eCQM Update 2018 EP-EC and EH",
        "eCQM Update 4Q2017 EH",
        "C-CDA R2.1 2017-06-09",
        "eCQM Update 2017-05-05",
        "MU2 Update 2017-01-06",
        "C-CDA R1.1 2016-06-23",
        "MU2 Update 2016-04-01",
        "MU2 Update 2015-05-01",
        "MU2 EP Update 2014-05-30",
        "MU2 EH Update 2014-04-01",
        "MU2 EP Update 2013-06-14",
        "MU2 EH Update 2013-04-01",
        "MU2 Update 2012-12-21",
        "MU2 Update 2012-10-25"]

      assert_equal expected_profiles, @api.get_profile_names
    end
  end

  test 'get_program_names' do
    VCR.use_cassette("vsac_util_get_programs") do
      expected_programs = ["CMS Hybrid", "CMS eCQM", "HL7 C-CDA"]

      assert_equal expected_programs, @api.get_program_names
    end
  end

  test 'get_program_details with default constant program' do
    VCR.use_cassette("vsac_util_get_program_details_CMS_eCQM") do
      program_info = @api.get_program_details

      assert_equal "CMS eCQM", program_info['name']
      assert_equal 14, program_info['release'].count
    end
  end

  test 'get_program_details with default config program' do
    VCR.use_cassette("vsac_util_get_program_details_CMS_Hybrid") do
      # Clone the config and add a program that will be used as the default program
      config = APP_CONFIG['vsac'].clone
      config[:program] = "CMS Hybrid"
      configuredApi = Util::VSAC::VSACAPI.new(config: config)
      program_info = configuredApi.get_program_details

      assert_equal "CMS Hybrid", program_info['name']
      assert_equal 1, program_info['release'].count
    end
  end

  test 'get_program_details with provided program' do
    VCR.use_cassette("vsac_util_get_program_details_HL7_C-CDA") do
      program_info = @api.get_program_details('HL7 C-CDA')

      assert_equal "HL7 C-CDA", program_info['name']
      assert_equal 3, program_info['release'].count
    end
  end

  test 'get_program_details for invalid program' do
    VCR.use_cassette("vsac_util_get_program_details_invalid") do
      assert_raise Util::VSAC::VSACProgramNotFoundError do
        @api.get_program_details('Fake Program')
      end
    end
  end

  test 'get_program_release_names with default constant program' do
    VCR.use_cassette("vsac_util_get_program_details_CMS_eCQM") do
      expected_releases = ["eCQM Update 2018-05-04",
        "eCQM Update 2018 EP-EC and EH",
        "eCQM Update 4Q2017 EH",
        "eCQM Update 2017-05-05",
        "MU2 Update 2017-01-06",
        "MU2 Update 2016-04-01",
        "MU2 Update 2015-05-01",
        "MU2 EP Update 2014-07-01",
        "MU2 EP Update 2014-05-30",
        "MU2 EH Update 2014-04-01",
        "MU2 EP Update 2013-06-14",
        "MU2 EH Update 2013-04-01",
        "MU2 Update 2012-12-21",
        "MU2 Update 2012-10-25"]

      releases = @api.get_program_release_names

      assert_equal expected_releases, releases
    end
  end

  test 'get_program_release_names with default config program' do
    VCR.use_cassette("vsac_util_get_program_details_CMS_Hybrid") do
      # Clone the config and add a program that will be used as the default program
      config = APP_CONFIG['vsac'].clone
      config[:program] = "CMS Hybrid"
      configuredApi = Util::VSAC::VSACAPI.new(config: config)

      expected_releases = ["CMS 2018 IQR Voluntary Hybrid Reporting"]

      releases = configuredApi.get_program_release_names

      assert_equal expected_releases, releases
    end
  end

  test 'get_program_release_names with provided program' do
    VCR.use_cassette("vsac_util_get_program_details_HL7_C-CDA") do
      expected_releases = ["C-CDA R2.1 2018-02-01",
        "C-CDA R2.1 2017-06-09",
        "C-CDA R1.1 2016-06-23"]

      releases = @api.get_program_release_names('HL7 C-CDA')

      assert_equal expected_releases, releases
    end
  end

  test 'get_program_release_names for invalid program' do
    VCR.use_cassette("vsac_util_get_program_details_invalid") do
      assert_raise Util::VSAC::VSACProgramNotFoundError do
        @api.get_program_release_names('Fake Program')
      end
    end
  end

  test 'get_latest_profile_for_program for valid program' do
    VCR.use_cassette("vsac_util_get_latest_profile_for_program_CMS_eCQM") do
      latest_profile = @api.get_latest_profile_for_program('CMS eCQM')
      assert_equal "eCQM Update 2018-05-04", latest_profile
    end
  end

  test 'get_latest_profile_for_program for default program' do
    VCR.use_cassette("vsac_util_get_latest_profile_for_program_CMS_eCQM") do
      latest_profile = @api.get_latest_profile_for_program
      assert_equal "eCQM Update 2018-05-04", latest_profile
    end
  end

  test 'get_latest_profile_for_program for invalid program' do
    VCR.use_cassette("vsac_util_get_latest_profile_for_program_invalid") do
      assert_raise Util::VSAC::VSACProgramNotFoundError do
        @api.get_latest_profile_for_program('Fake Program')
      end
    end
  end
end
