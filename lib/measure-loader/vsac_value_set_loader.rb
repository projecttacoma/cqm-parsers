module Measures
  # Utility class for loading value sets
  class VSACValueSetLoader
    attr_accessor :vsac_options, :vs_data_cache

    def initialize(options)
      options.symbolize_keys!
      @vsac_options = options[:options]
      @vsac_ticket_granting_ticket = options[:ticket_granting_ticket]
      @vsac_username = options[:username]
      @vsac_password = options[:password]
      @vs_data_cache = {}
    end

    def retrieve_and_modelize_value_sets_from_vsac(value_sets, measure_id = nil)
      vs_models = []
      needed_value_sets = []
      
      value_sets.each do |value_set|
        vs_vsac_options = make_specific_value_set_options(value_set)
        query_version = determine_query_version(vs_vsac_options, measure_id)

        cache_key = [value_set[:oid], query_version]
        vs_model = @vs_data_cache[cache_key]
        if vs_model.present?
          vs_models << vs_model
        else
          needed_value_sets << {value_set:  value_set, 
                                vs_vsac_options: vs_vsac_options,
                                query_version: query_version,
                                cache_key: cache_key}
        end
      end

      vs_responses = vs_api.get_multiple_valuesets(needed_value_sets)

      [needed_value_sets,vs_responses].transpose.each do |needed_vs,vs_data|
        vs_model = modelize_value_set(vs_data, needed_vs[:query_version])
        @vs_data_cache[needed_vs[:cache_key]] = vs_model
        vs_models << vs_model
      end

      puts "\tloaded #{needed_value_sets.size} value sets from vsac, #{value_sets.size - needed_value_sets.size} from cache"
      return vs_models
    end

    private

    def vs_api
      return @api if @api.present?
      @api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: @vsac_ticket_granting_ticket, username: @vsac_username, password: @vsac_password)
      return @api
    end

    def get_ticket_granting_ticket(vsac_username, vsac_password)
      raise Util::VSAC::VSACNoCredentialsError.new if vsac_username.nil? || vsac_password.nil?

      api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], username: vsac_username, password: vsac_password)
      ticket_granting_ticket = api.ticket_granting_ticket
      return ticket_granting_ticket
    end

    def determine_query_version(vs_vsac_options, measure_id)
      return "Draft-#{measure_id}" if vs_vsac_options[:include_draft] == true
      return "Profile:#{vs_vsac_options[:profile]}" if vs_vsac_options[:profile]
      return vs_vsac_options[:version] if vs_vsac_options[:version]
      return "Release:#{vs_vsac_options[:release]}" if vs_vsac_options[:release]
      return ""
    end

    def make_specific_value_set_options(value_set)
      # If we are allowing measure_defined value sets, determine vsac_options for this value set based on elm info.
      if @vsac_options[:measure_defined]
        return { profile: value_set[:profile] } unless value_set[:profile].nil?
        return { version: value_set[:version] } unless value_set[:version].nil?
      end
      return @vsac_options
    end

    def modelize_value_set(vsac_xml_response, query_version)
      doc = Nokogiri::XML(vsac_xml_response)
      doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
      vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet|/vs:RetrieveMultipleValueSetsResponse/vs:DescribedValueSet")
      vs = CQM::ValueSet.new(
        oid: vs_element["ID"],
        display_name: vs_element["displayName"],
        version: vs_element["version"] == "N/A" ? query_version : vs_element["version"],
        concepts: extract_concepts(vs_element)
      )
      return vs
    end

    def extract_concepts(vs_element)
      concepts = vs_element.xpath("//vs:Concept").collect do |con|
        CQM::Concept.new(code: con["code"], 
                         code_system_name: con["codeSystemName"],
                         code_system_version: con["codeSystemVersion"],
                         code_system_oid: con["codeSystem"],
                         display_name: con["displayName"])
      end
      return concepts
    end

  end
end
