require 'test_helper'
require 'vcr_setup.rb'

# Tests that ensure VSAC utility functions fetch and parse correct data.
class VSACAPIUtilTest < Minitest::Test
  def setup
    @api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'])
  end

  def test_get_profile_names
    VCR.use_cassette("vsac_util_get_profiles") do
      # NOTE: The expected profiles will change as profiles are published.
      expected_profiles = ["Most Recent Code System Versions in VSAC",
                           "RCKMS Release 1.0 2018-10-31",
                           "eCQM Update 2018-09-17",
                           "C-CDA R2.1 2018-06-15",
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

  def test_get_program_names
    VCR.use_cassette("vsac_util_get_programs") do
      expected_programs = ["CMS Hybrid", "CMS eCQM", "HL7 C-CDA"]

      assert_equal expected_programs, @api.get_program_names
    end
  end

  def test_get_program_details_with_default_constant_program
    VCR.use_cassette("vsac_util_get_program_details_CMS_eCQM") do
      program_info = @api.get_program_details

      assert_equal "CMS eCQM", program_info['name']
      # NOTE: this count will increase as new releases are published.
      assert_equal 15, program_info['release'].count
    end
  end

  def test_get_program_details_with_default_config_program
    VCR.use_cassette("vsac_util_get_program_details_CMS_Hybrid") do
      # Clone the config and add a program that will be used as the default program
      config = APP_CONFIG['vsac'].clone
      config[:program] = "CMS Hybrid"
      configured_api = Util::VSAC::VSACAPI.new(config: config)
      program_info = configured_api.get_program_details

      assert_equal "CMS Hybrid", program_info['name']
      assert_equal 1, program_info['release'].count
    end
  end

  def test_get_program_details_with_provided_program
    VCR.use_cassette("vsac_util_get_program_details_HL7_C-CDA") do
      program_info = @api.get_program_details('HL7 C-CDA')

      assert_equal "HL7 C-CDA", program_info['name']
      # NOTE: release count will change as releases are made.
      assert_equal 4, program_info['release'].count
    end
  end

  def test_get_program_details_for_invalid_program
    VCR.use_cassette("vsac_util_get_program_details_invalid") do
      assert_raises Util::VSAC::VSACProgramNotFoundError do
        @api.get_program_details('Fake Program')
      end
    end
  end

  def test_get_program_release_names_with_default_constant_program
    VCR.use_cassette("vsac_util_get_program_details_CMS_eCQM") do
      # NOTE: expected_releases will changes as updates are published.
      expected_releases = ["eCQM Update 2018-09-17",
                           "eCQM Update 2018-05-04",
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

  def test_get_program_release_names_with_default_config_program
    VCR.use_cassette("vsac_util_get_program_details_CMS_Hybrid") do
      # Clone the config and add a program that will be used as the default program
      config = APP_CONFIG['vsac'].clone
      config[:program] = "CMS Hybrid"
      configured_api = Util::VSAC::VSACAPI.new(config: config)

      expected_releases = ["CMS 2018 IQR Voluntary Hybrid Reporting"]

      releases = configured_api.get_program_release_names

      assert_equal expected_releases, releases
    end
  end

  def test_get_program_release_names_with_provided_program
    VCR.use_cassette("vsac_util_get_program_details_HL7_C-CDA") do
      # NOTE: the expected releases will change as new releases are published.
      expected_releases = ["C-CDA R2.1 2018-06-15",
                           "C-CDA R2.1 2018-02-01",
                           "C-CDA R2.1 2017-06-09",
                           "C-CDA R1.1 2016-06-23"]

      releases = @api.get_program_release_names('HL7 C-CDA')

      assert_equal expected_releases, releases
    end
  end

  def test_get_program_release_names_for_invalid_program
    VCR.use_cassette("vsac_util_get_program_details_invalid") do
      assert_raises Util::VSAC::VSACProgramNotFoundError do
        @api.get_program_release_names('Fake Program')
      end
    end
  end

  def test_get_latest_profile_for_program_for_valid_program
    VCR.use_cassette("vsac_util_get_latest_profile_for_program_CMS_eCQM") do
      latest_profile = @api.get_latest_profile_for_program('CMS eCQM')
      assert_equal "eCQM Update 2018-09-17", latest_profile
    end
  end

  def test_get_latest_profile_for_program_for_default_program
    VCR.use_cassette("vsac_util_get_latest_profile_for_program_CMS_eCQM") do
      latest_profile = @api.get_latest_profile_for_program
      # NOTE: this profile will change after the recording of this cassette.
      assert_equal "eCQM Update 2018-09-17", latest_profile
    end
  end

  def test_get_latest_profile_for_program_for_invalid_program
    VCR.use_cassette("vsac_util_get_latest_profile_for_program_invalid") do
      assert_raises Util::VSAC::VSACProgramNotFoundError do
        @api.get_latest_profile_for_program('Fake Program')
      end
    end
  end
end
