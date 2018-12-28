require 'rest_client'
require 'uri'
require 'typhoeus'

module Measures
  module VSAC

    # Generic VSAC related exception.
    class VSACError < StandardError
    end

    # Error represnting a not found response from the API. Includes OID for reporting to user.
    class VSNotFoundError < VSACError
      attr_reader :oid
      def initialize(oid)
        super("Value Set (#{oid}) was not found.")
        @oid = oid
      end
    end

    # Error represnting a program not found response from the API.
    class VSACProgramNotFoundError < VSACError
      attr_reader :oid
      def initialize(program)
        super("VSAC Program #{program} does not exist.")
      end
    end

    # Error represnting a response from the API that had no concepts.
    class VSEmptyError < VSACError
      attr_reader :oid
      def initialize(oid)
        super("Value Set (#{oid}) is empty.")
        @oid = oid
      end
    end

    # Raised when the ticket granting ticket has expired.
    class VSACTicketExpiredError < VSACError
      def initialize
        super('VSAC session expired. Please re-enter credentials and try again.')
      end
    end

    # Raised when the user credentials were invalid.
    class VSACInvalidCredentialsError < VSACError
      def initialize
        super('VSAC ULMS credentials are invalid.')
      end
    end

    # Raised when a call requiring auth is attempted when no ticket_granting_ticket or credentials were provided.
    class VSACNoCredentialsError < VSACError
      def initialize
        super('VSAC ULMS credentials were not provided.')
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

      # The ticket granting that will be obtained if needed. Accessible so it may be stored in user session.
      # Is a hash of the :ticket and time it :expires.
      attr_reader :ticket_granting_ticket

      ##
      # Creates a new VSACAPI. If credentials were provided they are checked now. If no credentials
      # are provided then the API can still be used for utility methods.
      #
      # Options for the API are passed in as a hash.
      # * config -
      def initialize(options)
        # check that :config exists and has needed fields
        if options[:config].nil?
          raise VSACArgumentError.new("Required param :config is missing or empty.")
        else
          symbolized_config = options[:config].symbolize_keys
          if check_config symbolized_config
            @config = symbolized_config
          else
            raise VSACArgumentError.new("Required param :config is missing required URLs.")
          end
        end

        # if a ticket_granting_ticket was passed in, check it and raise errors if found
        # username and password will be ignored
        if !options[:ticket_granting_ticket].nil?
          provided_ticket_granting_ticket = options[:ticket_granting_ticket]
          if provided_ticket_granting_ticket[:ticket].nil? || provided_ticket_granting_ticket[:expires].nil?
            raise VSACArgumentError.new("Optional param :ticket_granting_ticket is missing :ticket or :expires")
          end

          # check if it has expired
          if Time.now > provided_ticket_granting_ticket[:expires]
            raise VSACTicketExpiredError.new
          end

          # ticket granting ticket looks good
          @ticket_granting_ticket = { ticket: provided_ticket_granting_ticket[:ticket],
            expires: provided_ticket_granting_ticket[:expires] }

        # if username and password were provided use them to get a ticket granting ticket
        elsif !options[:username].nil? && !options[:password].nil?
          @ticket_granting_ticket = get_ticket_granting_ticket(options[:username], options[:password])
        end
      end

      ##
      # Gets the list of profiles. This may be used without credentials.
      #
      # Returns a list of profile names. These are kept in the order that VSAC provides them in.
      def get_profile_names
        profiles_response = RestClient.get("#{@config[:utility_url]}/profiles")
        profiles = []

        # parse xml response and get text content of each profile element
        doc = Nokogiri::XML(profiles_response)
        profile_list = doc.at_xpath("/ProfileList")
        profile_list.xpath("//profile").each do |profile|
          profiles << profile.text
        end

        return profiles
      end

      ##
      # Gets the list of programs. This may be used without credentials.
      #
      # Returns a list of program names. These are kept in the order that VSAC provides them in.
      def get_program_names
        programs_response = RestClient.get("#{@config[:utility_url]}/programs")
        program_names = []

        # parse json response and return the names of the programs
        programs_info = JSON.parse(programs_response)['Program']
        programs_info.each do |program|
          program_names << program['name']
        end

        return program_names
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
        if program.nil?
          program = @config.fetch(:program, DEFAULT_PROGRAM)
        end

        begin
          # parse json response and return it
          return JSON.parse(RestClient.get("#{@config[:utility_url]}/program/#{ERB::Util.url_encode(program)}"))
        rescue RestClient::ResourceNotFound
          raise VSACProgramNotFoundError.new(program)
        end
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
        if program.nil?
          program = @config.fetch(:program, DEFAULT_PROGRAM)
        end

        begin
          # parse json response and return it
          parsedResponse = JSON.parse(RestClient.get("#{@config[:utility_url]}/program/#{ERB::Util.url_encode(program)}/latest%20profile"))

          # As of 5/17/18 VSAC does not return 404 when an invalid profile is provided. It just doesnt fill the name
          # attribute in the 200 response. We need to check this.
          if !parsedResponse['name'].nil?
            return parsedResponse['name']
          else
            raise VSACProgramNotFoundError.new(program)
          end

        # keeping this rescue block in case the API is changed to return 404 for invalid profile
        rescue RestClient::ResourceNotFound
          raise VSACProgramNotFoundError.new(program)
        end
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
        releases = []

        # pull just the release names out
        program_details['release'].each do |release|
          releases << release['name']
        end

        return releases
      end


      def get_multiple_valuesets(needed_value_sets)
        raise VSACNoCredentialsError.new unless @ticket_granting_ticket
        raise VSACTicketExpiredError.new if Time.now > @ticket_granting_ticket[:expires]

        vs_responses = get_multiple_valueset_raw_responses(needed_value_sets)
        vs_datas = [needed_value_sets,vs_responses].transpose.map do |needed_vs,vs_response|
          expected_oid = needed_vs[:value_set][:oid]
          process_and_validate_vsac_response(vs_response, expected_oid)
        end

        return vs_datas
      end

      def process_and_validate_vsac_response(vs_response, expected_oid)
        if vs_response.response_code == 404
          raise VSNotFoundError.new(expected_oid)
        elsif vs_response.response_code != 200
          raise VSACError.new("Error code #{vs_response.response_code} from VSAC for #{expected_oid}.")
        end

        vs_data = vs_response.body.force_encoding("utf-8")
        begin
          doc = Nokogiri::XML(vs_data)
          doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
          vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet|/vs:RetrieveMultipleValueSetsResponse/vs:DescribedValueSet")
          concepts = vs_element.xpath("//vs:Concept")
        rescue
          raise VSACError.new("Could not parse VSAC response for #{expected_oid}. Body: #{vs_data}")
        end

        raise Util::VSAC::VSNotFoundError.new(expected_oid) if !(vs_element && vs_element['ID'] == expected_oid)
        raise Util::VSAC::VSEmptyError.new(expected_oid) if concepts.empty?
        return vs_data
      end

      def get_multiple_valueset_raw_responses(needed_value_sets)
        service_tickets = get_service_tickets(needed_value_sets.size)

        hydra = Typhoeus::Hydra.new
        requests = needed_value_sets.map do |n| 
          request = get_valueset_request(n[:value_set][:oid], service_tickets.pop, n[:vs_vsac_options])
          hydra.queue(request)
          request
        end

        hydra.run
        responses = requests.map { |request| request.response }
        return responses
      end

      def get_service_tickets(amount)
        hydra = Typhoeus::Hydra.new
        requests = amount.times.map do
          request = create_service_ticket_request
          hydra.queue(request)
          request
        end

        hydra.run
        tickets = requests.map { |request| request.response.body }
        return tickets
      end

      def create_service_ticket_request
        return Typhoeus::Request.new(
            "#{@config[:auth_url]}/Ticket/#{@ticket_granting_ticket[:ticket]}", 
            method: :post,
            params: { service: TICKET_SERVICE_PARAM})
      end


      ##
      # Gets a valueset. This requires credentials.
      #
      def get_valueset(oid, options = {})
        # base parameter oid is always needed
        params = { id: oid }

        # release parameter, should be used moving forward
        if !options[:release].nil?
          params[:release] = options[:release]
        end

        # profile parameter, may be needed for getting draft value sets
        if !options[:profile].nil?
          params[:profile] = options[:profile]
          if !options[:include_draft].nil?
            params[:includeDraft] = if !!options[:include_draft] then 'yes' else 'no' end
          end
        else
          if !options[:include_draft].nil?
            raise VSACArgumentError.new("Option :include_draft requires :profile to be provided.")
          end
        end

        # version parameter, rarely used
        if !options[:version].nil?
          params[:version] = options[:version]
        end

        # get a new service ticket
        params[:ticket] = get_ticket

        # run request
        begin
          return RestClient.get("#{@config[:content_url]}/RetrieveMultipleValueSets", params: params)
        rescue RestClient::ResourceNotFound
          raise VSNotFoundError.new(oid)
        rescue RestClient::InternalServerError
          raise VSACError.new("Server error response from VSAC for (#{oid}).")
        end
      end

      def get_valueset_request(oid, ticket, options = {})
        # base parameter oid is always needed
        params = { id: oid }

        # release parameter, should be used moving forward
        if !options[:release].nil?
          params[:release] = options[:release]
        end

        # profile parameter, may be needed for getting draft value sets
        if !options[:profile].nil?
          params[:profile] = options[:profile]
          if !options[:include_draft].nil?
            params[:includeDraft] = if !!options[:include_draft] then 'yes' else 'no' end
          end
        else
          if !options[:include_draft].nil?
            raise VSACArgumentError.new("Option :include_draft requires :profile to be provided.")
          end
        end

        # version parameter, rarely used
        if !options[:version].nil?
          params[:version] = options[:version]
        end

        params[:ticket] = ticket

        return Typhoeus::Request.new("#{@config[:content_url]}/RetrieveMultipleValueSets", params: params)
      end

      private
      def get_ticket
        # if there is no ticket granting ticket then we should raise an error
        raise VSACNoCredentialsError.new unless @ticket_granting_ticket
        # if the ticket granting ticket has expired, throw an error
        raise VSACTicketExpiredError.new if Time.now > @ticket_granting_ticket[:expires]

        # attempt to get a ticket
        begin
          ticket = RestClient.post("#{@config[:auth_url]}/Ticket/#{@ticket_granting_ticket[:ticket]}", service: TICKET_SERVICE_PARAM)
          return ticket.to_s
        rescue RestClient::Unauthorized
          @ticket_granting_ticket[:expires] = Time.now
          raise VSACTicketExpiredError.new
        end
      end

      def get_ticket_granting_ticket(username, password)
        begin
          ticket = RestClient.post("#{@config[:auth_url]}/Ticket", username: username, password: password)
          return { ticket: String.new(ticket), expires: Time.now + 8.hours }
        rescue RestClient::Unauthorized
          raise VSACInvalidCredentialsError.new
        end
      end

      # Checks to ensure the API config has all necessary fields
      def check_config(config)
        return config != nil &&
               !config[:auth_url].nil? &&
               !config[:content_url].nil? &&
               !config[:utility_url].nil?
      end

    end

  end
end
