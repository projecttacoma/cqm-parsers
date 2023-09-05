module Measures
  # Utility class for loading value sets
  class VSACValueSetLoader
    attr_accessor :vsac_options, :vs_model_cache
    VS_URL_PRIFIX = 'http://cts.nlm.nih.gov/fhir/ValueSet/'

    def initialize(options)
      options.symbolize_keys!
      @vsac_options = options[:options]
      @vsac_api_key = options[:vsac_api_key]
      @vs_model_cache = {}
    end

    def retrieve_and_modelize_value_sets_from_vsac(value_sets, code_systems_mapping)
      vs_models = []
      needed_value_sets = []

      value_sets.each do |value_set|
        raw_value_set = value_set.dup
        vs_vsac_options = make_specific_value_set_options(raw_value_set)
        query_version = determine_query_version(vs_vsac_options)
        raw_value_set[:oid] = get_value_set_oid_from_url(raw_value_set[:oid])
        cache_key = [raw_value_set[:oid], query_version]
        vs_model = @vs_model_cache[cache_key]
        if vs_model.present?
          vs_models << vs_model
        else
          needed_value_sets << {value_set:  raw_value_set,
                                vs_vsac_options: vs_vsac_options,
                                query_version: query_version,
                                cache_key: cache_key}
        end
      end

      vs_responses = load_api.get_multiple_valuesets(needed_value_sets)

      [needed_value_sets,vs_responses].transpose.each do |needed_vs,vs_data|
        vs_model = modelize_value_set(vs_data, needed_vs[:query_version], code_systems_mapping)
        @vs_model_cache[needed_vs[:cache_key]] = vs_model
        vs_models << vs_model
      end

      puts "\tloaded #{needed_value_sets.size} value sets from vsac, #{value_sets.size - needed_value_sets.size} from cache"
      return vs_models
    end

    private

    def load_api
      return @api if @api.present?
      @api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], api_key: @vsac_api_key)
      return @api
    end

    def determine_query_version(vs_vsac_options)
      return "Draft" if vs_vsac_options[:include_draft] == true
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

    def modelize_value_set(vsac_xml_response, query_version, code_systems_mapping)
      doc = Nokogiri::XML(vsac_xml_response)
      doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
      vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet|/vs:RetrieveMultipleValueSetsResponse/vs:DescribedValueSet")
      FHIR::ValueSet.new(
        fhirId: vs_element['ID'],
        url: FHIR::PrimitiveUri.transform_json("#{VS_URL_PRIFIX}#{vs_element['ID']}", nil),
        title: FHIR::PrimitiveString.transform_json(vs_element["displayName"], nil),
        name: FHIR::PrimitiveString.transform_json(vs_element["displayName"], nil),
        version: FHIR::PrimitiveString.transform_json(
          vs_element["version"] == "N/A" ? query_version : vs_element["version"], nil
        ),
        compose: prepare_code_system_concepts(vs_element, code_systems_mapping)
      )
    end

    def prepare_code_system_concepts(vs_element, code_systems_mapping)
      code_systems = vs_element.xpath("//vs:Concept").group_by { |concept| concept['codeSystemName']}
      vsc_include = []
      code_systems.each do |code_system_name, concepts|
        vs_concepts = concepts.collect do |concept|
          FHIR::ValueSetComposeIncludeConcept.new(
            code: FHIR::PrimitiveCode.transform_json(concept['code'], nil),
            display: FHIR::PrimitiveString.transform_json(concept['displayName'], nil)
          )
        end
        oid = concepts.first['codeSystem']
        code_system_uri =  code_systems_mapping.dig('by_oid', oid) || code_systems_mapping.dig('by_name', code_system_name)
        vsc_include << FHIR::ValueSetComposeInclude.new(
          system: FHIR::PrimitiveUri.transform_json(code_system_uri, nil),
          version: FHIR::PrimitiveString.transform_json(concepts[0]['codeSystemVersion'], nil),
          concept: vs_concepts
        )
      end
      FHIR::ValueSetCompose.new(include: vsc_include)
    end

    def get_value_set_oid_from_url(value_set_url)
      value_set_oid_regex = /([0-2])((\.0)|(\.[1-9][0-9]*))*$/
      value_set_oid = value_set_url.match(value_set_oid_regex)
      value_set_oid.to_s
    end
  end
end
