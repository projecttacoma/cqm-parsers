module Measures

  # Utility class for loading value sets
  class ValueSetLoader
    attr_accessor :vsac_options, :user, :vs_data_cache

    def initialize(vsac_options, vsac_ticket_granting_ticket, user=nil)
      @vsac_options = vsac_options
      @user = user

      @vs_data_cache = vs_data_cache
      @api = Util::VSAC::VSACAPI.new(config: APP_CONFIG['vsac'], ticket_granting_ticket: vsac_ticket_granting_ticket)
    end

    def save_value_sets(value_set_models)
      #loaded_value_sets = HealthDataStandards::SVS::ValueSet.all.map(&:oid)
      value_set_models.each do |vsm|
        HealthDataStandards::SVS::ValueSet.by_user(@user).where(oid: vsm.oid).delete_all()
        vsm.user = @user
        #bundle id for user should always be the same 1 user to 1 bundle
        #using this to allow cat I generation without extensive modification to HDS
        vsm.bundle = @user.bundle if (@user && @user.respond_to?(:bundle))
        vsm.save!
      end
    end

    def get_value_set_models(value_set_oids)
      HealthDataStandards::SVS::ValueSet.by_user(@user).in(oid: value_set_oids)
    end

    def load_value_sets(value_sets, measure_id=nil)
      value_set_models = []
      vsac_query_count = 0
      existing_value_set_map = {}

      errors = {}

      RestClient.proxy = ENV["http_proxy"]
      value_sets.each do |value_set|
        # The vsac_options that will be used for this specific value set. Default to using passed in options from measures controller
        vs_vsac_options = @vsac_options

        # If we are allowing measure_defined value sets, determine vsac_options for this value set based on elm info.
        if @vsac_options[:measure_defined] == true
          if !value_set[:profile].nil?
            vs_vsac_options = { profile: value_set[:profile] }
          elsif !value_set[:version].nil?
            vs_vsac_options = { version: value_set[:version] }
          end
          # if no parseable options in the ELM were found, we stick with the passed in options from measures controller
        end

        # Determine version to store value sets as after parsing and to use to looking for existing set.
        query_version = ""
        if vs_vsac_options[:include_draft] == true
          query_version = "Draft-#{measure_id}" # Unique draft version based on measure id
        elsif vs_vsac_options[:profile]
          query_version = "Profile:#{vs_vsac_options[:profile]}" # Profile calls return 'N/A' so note profile use.
        elsif vs_vsac_options[:version]
          query_version = vs_vsac_options[:version]
        elsif vs_vsac_options[:release]
          query_version = "Release:#{vs_vsac_options[:release]}"
        end

        # TODO: remove the usage of existing value sets. future work will be always fetching value sets from VSAC and
        # associating them with the new measure.
        # check if we already have this valuset loaded for this user
        # set = HealthDataStandards::SVS::ValueSet.where({user_id: user.id, oid: value_set[:oid], version: query_version}).first()
        # delete existing if we are doing include_draft option sinc the existing may be stale. note that this may delete 
        # and effectively replace value sets for a measure load that may fail. Unintentionally updating the value sets.
        # if (vs_vsac_options[:include_draft] && set)
        #   set.delete
        #   set = nil
        # end
        # # use the existing value set if it exists
        # if (set)
        #   existing_value_set_map[set.oid] = set

        cache_key = [value_set[:oid], query_version]
        set = @vs_data_cache[cache_key]
        if set.nil?
          set = load_value_set_from_vsac(value_set, vs_vsac_options)
          set.save!
          vsac_query_count += 1
          @vs_data_cache[cache_key] = set
        end

        existing_value_set_map[set.oid] = set
        // if we are using the oid as a key, we cannot support multiple versions
        # end
      end

      puts "\tloaded #{vsac_query_count} value sets from vsac, #{value_sets.size - vsac_query_count} from cache"
      existing_value_set_map.values
    end

    def load_value_set_from_vsac(value_set, vs_vsac_options)
      vs_data = @api.get_valueset(value_set[:oid], vs_vsac_options)

      # there are some funky unicodes coming out of the vs response that are not in ASCII as the string reports to be
      vs_data.force_encoding("utf-8")

      doc = Nokogiri::XML(vs_data)
      doc.root.add_namespace_definition("vs","urn:ihe:iti:svs:2008")
      vs_element = doc.at_xpath("/vs:RetrieveValueSetResponse/vs:ValueSet|/vs:RetrieveMultipleValueSetsResponse/vs:DescribedValueSet")

      if !(vs_element && vs_element['ID'] == value_set[:oid])
        raise Util::VSAC::VSNotFoundError.new(value_set[:oid])
      end

      vs_element['id'] = value_set[:oid]
      set = HealthDataStandards::SVS::ValueSet.load_from_xml(doc)
      # make sure this value set has concepts, delete it and raise error if it is empty
      if set.concepts.empty?
        set.delete
        raise Util::VSAC::VSEmptyError.new(value_set[:oid])
      end
      set.user = @user

      # bundle id for user should always be the same 1 user to 1 bundle
      # using this to allow cat I generation without extensive modification to HDS
      set.bundle = @user.bundle if (@user && @user.respond_to?(:bundle))

      # As of 9/7/2017, when valuesets are retrieved from VSAC via profile, their version defaults to N/A
      # As such, we set the version to the profile with an indicator.
      set.version = query_version
      return set
    end
    
  end
end
