module Measures
  class ValueSetManager

    
    # Manages all of the CQL processing that is not related to the HQMF.
    def self.load_value_sets_and_process(elms, value_set_loader, user, measure_id=nil)
      # Depending on the value of the value set version, change it to null, strip out a substring or leave it alone.
      elms.each { |elm| modify_value_set_versions(elm) }

      # Grab the value sets from the elm
      elm_value_sets = []
      elms.each do | elm |
        (elm.dig('library','valueSets','def') || []).each do |value_set|
          elm_value_sets << {oid: value_set['id'], version: value_set['version'], profile: value_set['profile']}
        end
      end
      # Get Value Sets
      value_set_models = []
      # Only load value sets from VSAC if there is a ticket_granting_ticket.
      if !vsac_ticket_granting_ticket.nil?        
        value_set_models = value_set_loader.load_value_sets(elm_value_sets, measure_id)
      else
        # No vsac credentials were provided grab the valueset and valueset versions from the 'value_set_oid_version_object' on the existing measure
        db_measure = CqlMeasure.by_user(user).where(hqmf_set_id: measure_id).first
        unless db_measure.nil?
          measure_value_set_version_map = db_measure.value_set_oid_version_objects
          measure_value_set_version_map.each do |value_set|
            query_params = {user_id: user.id, oid: value_set['oid'], version: value_set['version']}
            value_set = HealthDataStandards::SVS::ValueSet.where(query_params).first()
            if value_set
              value_set_models << value_set
            else
              raise MeasureLoadingException.new "Value Set not found in database: #{query_params}"
            end
          end
        end
      end

      # Get code systems and codes for all value sets in the elm.
      all_codes_and_code_names = get_all_codes_and_code_names(value_set_models)

      # Generate single reference code objects and a complete list of code systems and codes for the measure.
      single_code_references, all_codes_and_code_names = generate_and_store_single_code_references(elms, all_codes_and_code_names, user)

      # Add our new fake oids to measure value sets.
      all_value_set_oids = value_set_models.collect{|vs| vs.oid}
      single_code_references.each do |single_code|
        # Only add unique Direct Reference Codes
        unless all_value_set_oids.include?(single_code[:guid])
          all_value_set_oids << single_code[:guid]
        end
      end

      # Add a list of value set oids and their versions
      value_set_oid_version_objects = get_value_set_oid_version_objects(value_set_models, single_code_references)

      return all_codes_and_code_names.as_json

      # return {:all_value_set_oids => all_value_set_oids.as_json,
      #         :value_set_oid_version_objects => value_set_oid_version_objects.as_json,
      #         :single_code_references => single_code_references.as_json,
      #         :all_codes_and_code_names => all_codes_and_code_names.as_json}
    end
    

    def self.get_all_codes_and_code_names(value_sets)
      all_codes_and_code_names = {}
      value_sets.each do |value_set|
        code_sets = {}
        value_set.concepts.each do |code_set|
          binding.pry
          //TODO: move away from code system names?? not sure if relevant here
          code_sets[code_set.code_system_name] ||= []
          code_sets[code_set.code_system_name] << code_set.code
        end
        all_codes_and_code_names[value_set.oid] = code_sets
      end

      return all_codes_and_code_names
    end


    # Returns a list of objects that include the valueset oids and their versions
    def self.get_value_set_oid_version_objects(value_sets, single_code_references)
      # [LDC] need to make this an array of objects instead of a hash because Mongo is
      # dumb and *let's you* have dots in keys on object creation but *doesn't let you*
      # have dots in keys on object update or retrieve....
      vs_oid_version_objects = value_sets.map { |vs| {:oid => vs.oid, :version => vs.version} }

      single_code_references.each do |single_code|
        # Only add unique Direct Reference Codes to the object
        unless vs_oid_version_objects.include?({:oid => single_code[:guid], :version => ""})
          vs_oid_version_objects << {:oid => single_code[:guid], :version => ""}
        end
      end
      # Return a list of unique objects only
      vs_oid_version_objects
    end




    # Add single code references by finding the codes from the elm and creating new ValueSet objects
    # With a generated GUID as a fake oid.
    def self.generate_and_store_single_code_references(elms, all_codes_and_code_names, user)
      single_code_references = []
      # Add all single code references from each elm file
      elms.each do | elm |
        # Loops over all single codes and saves them as fake valuesets.
        (elm.dig('library','codes','def') || []).each do |code_reference|
          code_sets = {}

          # look up the referenced code system
          code_system_def = elm['library']['codeSystems']['def'].find { |code_sys| code_sys['name'] == code_reference['codeSystem']['name'] }

          code_system_name = code_system_def['id']
          code_system_version = code_system_def['version']

          code_sets[code_system_name] ||= []
          code_sets[code_system_name] << code_reference['id']
          # Generate a unique number as our fake "oid" based on parameters that identify the DRC
          code_hash = "drc-" + Digest::SHA2.hexdigest("#{code_system_name} #{code_reference['id']} #{code_reference['name']} #{code_system_version}")            
          # Keep a list of generated_guids and a hash of guids with code system names and codes.
          single_code_references << { guid: code_hash, code_system_name: code_system_name, code: code_reference['id'] }
          all_codes_and_code_names[code_hash] = code_sets
          # code_hashs are unique hashes, there's no sense in adding duplicates to the ValueSet collection
          if !HealthDataStandards::SVS::ValueSet.all().where(oid: code_hash, user_id: user.id).first()
            # Create a new "ValueSet" and "Concept" object and save.
            valueSet = HealthDataStandards::SVS::ValueSet.new({oid: code_hash, display_name: code_reference['name'], version: '' ,concepts: [], user_id: user.id})
            concept = HealthDataStandards::SVS::Concept.new({code: code_reference['id'], code_system_name: code_system_name, code_system_version: code_system_version, display_name: code_reference['name']})
            valueSet.concepts << concept
            valueSet.save!
          end
        end
      end
      # Returns a list of single code objects and a complete list of code systems and codes for all valuesets on the measure.
      return single_code_references, all_codes_and_code_names
    end


    def self.set_data_criteria_code_list_ids(hqmf_model_hash, single_code_references)
      # Loop over data criteria to search for data criteria that is using a single reference code.
      # Once found set the Data Criteria's 'code_list_id' to our fake oid. Do the same for source data criteria.
      hqmf_model_hash[:data_criteria].each do |data_criteria_name, data_criteria|
        if data_criteria[:inline_code_list] && !data_criteria[:code_list_id]
          # Check to see if inline_code_list contains the correct code_system and code for a direct reference code.
          data_criteria[:inline_code_list].each do |code_system, code_list|
            # Loop over all single code reference objects.
            single_code_references.each do |single_code_object|
              # If Data Criteria contains a matching code system, check if the correct code exists in the data critera values.
              # If both values match, set the Data Criteria's 'code_list_id' to the single_code_object_guid.
              if code_system == single_code_object[:code_system_name] && code_list.include?(single_code_object[:code])
                data_criteria[:code_list_id] = single_code_object[:guid]
                # Modify the matching source data criteria
                hqmf_model_hash[:source_data_criteria]["#{data_criteria_name}_source".to_sym][:code_list_id] = single_code_object[:guid]
              end
            end
          end
        end
      end
    end



    # Adjusting value set version data. If version is profile, set the version to nil
    def self.modify_value_set_versions(elm)
      (elm.dig('library','valueSets','def') || []).each do |value_set|
        # If value set has a version and it starts with 'urn:hl7:profile:' then set to nil
        if value_set['version'] && value_set['version'].include?('urn:hl7:profile:')
          value_set['profile'] = URI.decode(value_set['version'].split('urn:hl7:profile:').last)
          value_set['version'] = nil
        # If value has a version and it starts with 'urn:hl7:version:' then strip that and keep the actual version value.
        elsif value_set['version'] && value_set['version'].include?('urn:hl7:version:')
          value_set['version'] = URI.decode(value_set['version'].split('urn:hl7:version:').last)
        end
      end
    end

    # Removes 'urn:oid:' from ELM for Bonnie and Parse the JSON
    def self.remove_urnoid(json)
      if json.kind_of? Array
        json.each { |val| remove_urnoid(val) }
      elsif json.kind_of?( Hash)
        json.each_pair do |k,v|
          if v && v.kind_of?( String )
            json[k] = v.gsub! 'urn:oid:', '' 
          else
            remove_urnoid(v)
          end
        end
      end
    end


  end
end