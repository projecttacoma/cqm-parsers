module Measures

  # Utility class for loading value sets
  class ValueSetLoader
    attr_accessor :vsac_options, :vs_data_cache, :vsac_ticket_granting_ticket

    def initialize(vsac_options, vsac_ticket_granting_ticket)
      @vsac_options = vsac_options
      @vsac_ticket_granting_ticket = vsac_ticket_granting_ticket

      @vs_data_cache = {}
      @api = VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: vsac_ticket_granting_ticket)
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
                                query_version: query_version}
        end
      end

      vs_responses = @api.get_multiple_valuesets(needed_value_sets)

      [needed_value_sets,vs_responses].transpose.each do |needed_vs,vs_data|
        vs_model = modelize_value_set(vs_data, needed_vs[:query_version])
        cache_key = [needed_vs[:value_set][:oid], needed_vs[:value_set][:query_version]]
        @vs_data_cache[cache_key] = vs_model
        vs_models << vs_model
      end

      puts "\tloaded #{needed_value_sets.size} value sets from vsac, #{value_sets.size - needed_value_sets.size} from cache"
      return vs_models
    end

    private

    def determine_query_version(vs_vsac_options, measure_id)
      if vs_vsac_options[:include_draft] == true
        return "Draft-#{measure_id}" # Unique draft version based on measure id
      elsif vs_vsac_options[:profile]
        return "Profile:#{vs_vsac_options[:profile]}" # Profile calls return 'N/A' so note profile use.
      elsif vs_vsac_options[:version]
        return vs_vsac_options[:version]
      elsif vs_vsac_options[:release]
        return "Release:#{vs_vsac_options[:release]}"
      end
      raise ValueSetException.new("Unable to determine query version.")
    end

    def make_specific_value_set_options(value_set)
      # If we are allowing measure_defined value sets, determine vsac_options for this value set based on elm info.
      if @vsac_options[:measure_defined] == true
        return { profile: value_set[:profile] } if !value_set[:profile].nil?
        return { version: value_set[:version] } if !value_set[:version].nil?
      end
      return @vsac_options
    end

    def modelize_value_set(vsac_xml_response, query_version)
      doc = Nokogiri::XML(vsac_xml_response)
      doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
      vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet|/vs:RetrieveMultipleValueSetsResponse/vs:DescribedValueSet")
      raise error "BLAH" if vs_element.nil?
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
        CQM::Concept.new( code: con["code"], 
                          code_system_name: con["codeSystemName"],
                          code_system_version: con["codeSystemVersion"],
                          code_system_oid: con["codeSystem"],
                          display_name: con["displayName"])
      end
      return concepts
    end

  end
end
