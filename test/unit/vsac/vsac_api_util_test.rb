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
                           "eCQM Update 2024-05-02 - QA Analysis",
                           "eCQM Update 2024-05-02",
                           "C-CDA R2.1 2023-08-15",
                           "eCQM Update 2023-05-04",
                           "C-CDA R2.1 2022-08-10",
                           "eCQM Update 2022-05-05",
                           "C-CDA R2.1 2021-08-10",
                           "CMS Pre-rulemaking 2021-05-06",
                           "eCQM Update 2021-05-06",
                           "C-CDA R2.1 2020-07-13",
                           "CMS Pre-rulemaking eCQM 2020-05-07",
                           "eCQM Update 2020-05-07",
                           "CMS Pre-rulemaking eCQM 2019-08-30",
                           "C-CDA R2.1 2019-06-28",
                           "CMS Pre-rulemaking eCQM 2019-05-10",
                           "eCQM Update 2019-05-10"]

      assert_equal expected_profiles, @api.get_profile_names
    end
  end

  def test_get_program_names
    VCR.use_cassette("vsac_util_get_programs") do
      expected_programs = ["CMS FHIR eCQM Measure", "CMS Pre-rulemaking eCQM", "CMS eCQM and Hybrid Measure", "HL7 C-CDA"]

      assert_equal expected_programs, @api.get_program_names
    end
  end

  def test_get_program_details_with_default_constant_program
    VCR.use_cassette("vsac_util_get_program_details_CMS_eCQM") do
      program_info = @api.get_program_details

      assert_equal "CMS eCQM and Hybrid Measure", program_info['name']
      # NOTE: this count will increase as new releases are published.
      assert_equal 21, program_info['release'].count
    end
  end

  def test_get_program_details_with_default_config_program
    VCR.use_cassette("vsac_util_get_program_details_CMS_Pre_rulemaking") do
      # Clone the config and add a program that will be used as the default program
      config = APP_CONFIG['vsac'].clone
      config[:program] = "CMS Pre-rulemaking eCQM"
      configured_api = Util::VSAC::VSACAPI.new(config: config)
      program_info = configured_api.get_program_details

      assert_equal "CMS Pre-rulemaking eCQM", program_info['name']
      assert_equal 3, program_info['release'].count
    end
  end

  def test_get_program_details_with_provided_program
    VCR.use_cassette("vsac_util_get_program_details_HL7_C-CDA") do
      program_info = @api.get_program_details('HL7 C-CDA')

      assert_equal "HL7 C-CDA", program_info['name']
      # NOTE: release count will change as releases are made.
      assert_equal 9, program_info['release'].count
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
      expected_releases = ["eCQM Update 2024-05-02",
                           "eCQM Update 2023-05-04",
                           "eCQM Update 2022-05-05",
                           "eCQM Update 2021-05-06",
                           "eCQM Update 2020-05-07",
                           "eCQM Update 2019-05-10",
                           "eCQM Update 2018-09-17",
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
    VCR.use_cassette("vsac_util_get_program_details_CMS_Pre_rulemaking") do
      # Clone the config and add a program that will be used as the default program
      config = APP_CONFIG['vsac'].clone
      config[:program] = "CMS Pre-rulemaking eCQM"
      configured_api = Util::VSAC::VSACAPI.new(config: config)

      expected_releases = ["CMS Pre-rulemaking eCQM 2020-05-07",
                           "CMS Pre-rulemaking eCQM 2019-08-30",
                           "CMS Pre-rulemaking eCQM 2019-05-10"]

      releases = configured_api.get_program_release_names

      assert_equal expected_releases, releases
    end
  end

  def test_get_program_release_names_with_provided_program
    VCR.use_cassette("vsac_util_get_program_details_HL7_C-CDA") do
      # NOTE: the expected releases will change as new releases are published.
      expected_releases = ["C-CDA R2.1 2023-08-15",
                           "C-CDA R2.1 2022-08-10",
                           "C-CDA R2.1 2021-08-10",
                           "C-CDA R2.1 2020-07-13",
                           "C-CDA R2.1 2019-06-28",
                           "C-CDA R2.1 2018-06-15",
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
      latest_profile = @api.get_latest_profile_for_program('CMS eCQM and Hybrid Measure')
      assert_equal "eCQM Update 2024-05-02", latest_profile
    end
  end

  def test_get_latest_profile_for_program_for_default_program
    VCR.use_cassette("vsac_util_get_latest_profile_for_program_CMS_eCQM") do
      latest_profile = @api.get_latest_profile_for_program
      # NOTE: this profile will change after the recording of this cassette.
      assert_equal "eCQM Update 2024-05-02", latest_profile
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
