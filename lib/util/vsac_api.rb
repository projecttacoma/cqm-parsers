require 'typhoeus'
require 'uri'

module Util
  module VSAC
    # Generic VSAC related exception.
    class VSACError < StandardError
    end

    # Error representing a not found response from the API. Includes OID for reporting to user.
    class VSNotFoundError < VSACError
      attr_reader :oid
      def initialize(oid)
        super("Value Set (#{oid}) was not found.")
        @oid = oid
      end
    end

    # When VSAC responds with a 404
    class VSACNotFoundError < VSACError
      def initialize
        super('Resource not found.')
      end
    end

    # Error representing a program not found response from the API.
    class VSACProgramNotFoundError < VSACError
      attr_reader :oid
      def initialize(program)
        super("VSAC Program #{program} does not exist.")
      end
    end

    # Error representing a response from the API that had no concepts.
    class VSEmptyError < VSACError
      attr_reader :oid
      def initialize(oid)
        super("Value Set (#{oid}) is empty.")
        @oid = oid
      end
    end

    # Raised when the user credentials were invalid.
    class VSACInvalidCredentialsError < VSACError
      def initialize
        super('VSAC UMLS credentials are invalid.')
      end
    end

    # Raised when a call requiring auth is attempted when no ticket_granting_ticket or credentials were provided.
    class VSACNoCredentialsError < VSACError
      def initialize
        super('VSAC UMLS credentials were not provided.')
      end
    end

    # Raised when the arguments passed in are bad.
    class VSACArgumentError < VSACError
    end

    class VSACAPI
      # The default program to use for get_program_details and get_program_release_names calls.
      # This can be overriden by providing a :program in the config or by the single optional parameter for those
      # methods.
      DEFAULT_PROGRAM = "CMS eCQM"

      # This is the value of the service parameter passed when getting a ticket. This never changes.
      TICKET_SERVICE_PARAM = "http://umlsks.nlm.nih.gov"

      # Requester UMLS API KEY
      attr_reader :api_key

      ##
      # Creates a new VSACAPI. If credentials were provided they are checked now. If no credentials
      # are provided then the API can still be used for utility methods.
      #
      # Options for the API are passed in as a hash.
      # * config -
      def initialize(options)
        # check that :config exists and has needed fields
        raise VSACArgumentError.new("Required param :config is missing or empty.") if options[:config].nil?
        @config = options[:config].symbolize_keys
        unless check_config @config
          raise VSACArgumentError.new("Required param :config is missing required URLs.")
        end
        @api_key = options[:api_key]
      end

      ##
      # Gets the list of profiles. This may be used without credentials.
      #
      # Returns a list of profile names. These are kept in the order that VSAC provides them in.
      def get_profile_names
        profiles_response = http_get("#{@config[:utility_url]}/profiles")

        # parse xml response and get text content of each profile element
        doc = Nokogiri::XML(profiles_response)
        profile_list = doc.at_xpath("/ProfileList")
        return profile_list.xpath("//profile").map(&:text)
      end

      ##
      # Gets the list of programs. This may be used without credentials.
      #
      # Returns a list of program names. These are kept in the order that VSAC provides them in.
      def get_program_names
        programs_response = http_get_json("#{@config[:utility_url]}/programs")
        programs_info = programs_response['Program']
        return programs_info.map { |program| program['name'] }
      end

      ##
      # Gets the details for a program. This may be used without credentials.
      #
      # Optional parameter program is the program to request from the API. If it is not provided it will look for
      # a :program in the config passed in during construction. If there is no :program in the config it will use
      # the DEFAULT_PROGRAM constant for the program.
      #
      # Returns the JSON parsed response for program details.
      def get_program_details(program = nil)
        # if no program was provided use the one in the config or default in constant
        program = @config.fetch(:program, DEFAULT_PROGRAM) if program.nil?
        return http_get_json("#{@config[:utility_url]}/program/#{ERB::Util.url_encode(program)}")
      rescue VSACNotFoundError
        raise VSACProgramNotFoundError.new(program)
      end

      ##
      # Gets the latest profile for a program. This is a separate call from the program details call. It returns JSON
      # with only the name of the latest profile and the timestamp of the request. ex:
      #   {
      #     "name": "eCQM Update 2018-05-04",
      #     "requestTime": "2018-05-21 03:39:04 PM"
      #   }
      #
      # Optional parameter program is the program to request from the API. If it is not provided it will look for
      # a :program in the config passed in during construction. If there is no :program in the config it will use
      # the DEFAULT_PROGRAM constant for the program.
      #
      # Returns the name of the latest profile for the given program.
      def get_latest_profile_for_program(program = nil)
        # if no program was provided use the one in the config or default in constant
        program = @config.fetch(:program, DEFAULT_PROGRAM) if program.nil?

        # parse json response and return it
        parsed_response = http_get_json("#{@config[:utility_url]}/program/#{ERB::Util.url_encode(program)}/latest%20profile")

        # As of 5/17/18 VSAC does not return 404 when an invalid profile is provided. It just doesnt fill the name
        # attribute in the 200 response. We need to check this.
        raise VSACProgramNotFoundError.new(program) if parsed_response['name'].nil?
        return parsed_response['name']
      end

      ##
      # Gets the releases for a program. This may be used without credentials.
      #
      # Optional parameter program is the program to request from the API. If it is not provided it will look for
      # a :program in the config passed in during construction. If there is no :program in the config it will use
      # the DEFAULT_PROGRAM constant for the program.
      #
      # Returns a list of release names in a program. These are kept in the order that VSAC provides them in.
      def get_program_release_names(program = nil)
        program_details = get_program_details(program)
        return program_details['release'].map { |release| release['name'] }
      end

      ##
      # Gets a valueset. This requires credentials.
      #
      def get_valueset(oid, options = {})
        needed_vs = {value_set: {oid: oid}, vs_vsac_options: options}
        return get_multiple_valuesets([needed_vs])[0]
      end

      ##
      # Get multiple valuesets (executed in parallel). Requires credentials.
      #
      # Parameter needed_value_sets is an array of hashes, each hash should have at least:
      # hash = {vs_vsac_options: ___, value_set: {oid: ___} }
      #
      def get_multiple_valuesets(needed_value_sets)
        raise VSACNoCredentialsError.new unless @api_key

        vs_responses = get_multiple_valueset_raw_responses(needed_value_sets)
        vs_datas = [needed_value_sets,vs_responses].transpose.map do |needed_vs,vs_response|
          expected_oid = needed_vs[:value_set][:oid]
          process_and_validate_vsac_response(vs_response, expected_oid)
        end

        return vs_datas
      end

      private

      # Given a raw valueset response, process and validate
      def process_and_validate_vsac_response(vs_response, expected_oid)
        raise VSNotFoundError.new(expected_oid) if vs_response.response_code == 404
        validate_http_status_for_apikey_based_request(vs_response.response_code)

        vs_data = vs_response.body.force_encoding("utf-8")
        begin
          doc = Nokogiri::XML(vs_data)
          doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
          vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet|/vs:RetrieveMultipleValueSetsResponse/vs:DescribedValueSet")
          concepts = vs_element.xpath("//vs:Concept")
        rescue StandardError
          raise VSACError.new("Could not parse VSAC response for #{expected_oid}. Body: #{vs_data}")
        end

        raise Util::VSAC::VSNotFoundError.new(expected_oid) unless (vs_element && vs_element['ID'] == expected_oid)
        raise Util::VSAC::VSEmptyError.new(expected_oid) if concepts.empty?
        return vs_data
      end

      # Execute bulk requests for valuesets, return the raw Typheous responses (requests executed in parallel)
      def get_multiple_valueset_raw_responses(needed_value_sets)
        hydra = Typhoeus::Hydra.new(max_concurrency: 1) # Hydra executes multiple HTTP requests at once
        requests = needed_value_sets.map do |n|
          request = create_valueset_request(n[:value_set][:oid], n[:vs_vsac_options])
          hydra.queue(request)
          request
        end

        hydra.run
        responses = requests.map(&:response)
        return responses
      end

      # Create a typheous request for a valueset (this must be executed later)
      def create_valueset_request(oid, options = {})
        # base parameter oid is always needed
        params = { id: oid }
        # release parameter, should be used moving forward
        params[:release] = options[:release] unless options[:release].nil?

        # profile parameter, may be needed for getting draft value sets
        if options[:profile].present?
          params[:profile] = options[:profile]
          params[:includeDraft] = options[:include_draft] ? 'yes' : 'no' unless options[:include_draft].nil?
        end
        if !options[:include_draft].nil? && options[:profile].nil?
          raise VSACArgumentError.new("Option :include_draft requires :profile to be provided.")
        end

        # version parameter, rarely used
        params[:version] = options[:version] unless options[:version].nil?

        return Typhoeus::Request.new("#{@config[:content_url]}/RetrieveMultipleValueSets",
                                     params: params,
                                     userpwd: "apikey:#{@api_key}")
      end

      # Raise errors if http_status is not OK (200)
      def validate_http_status_for_apikey_based_request(http_status)
        if http_status == 401
          raise VSACInvalidCredentialsError.new
        end
        validate_http_status(http_status)
      end

      # Raise errors if http_status is not OK (200)
      def validate_http_status(http_status)
        return if http_status == 200
        if http_status == 0
          raise VSACError.new("Error communicating with VSAC.")
        elsif http_status == 404
          raise VSACNotFoundError.new
        else
          raise VSACError.new("HTTP Error code #{http_status} received from VSAC.")
        end
      end

      # Convenience function to perform an http get request (raises errors on failure)
      def http_get(url)
        response = Typhoeus.get(url)
        validate_http_status(response.response_code)
        return response.body
      end

      # Convenience function to perform an http get request and convert to JSON (raises errors on failure)
      def http_get_json(url)
        return JSON.parse(http_get(url))
      end

      # Checks to ensure the API config has all necessary fields
      def check_config(config)
        return !config.nil? &&
               !config[:auth_url].nil? &&
               !config[:content_url].nil? &&
               !config[:utility_url].nil?
      end
    end
  end
end
