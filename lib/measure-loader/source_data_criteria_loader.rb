module Measures
  class SourceDataCriteriaLoader

    def initialize(hqmf_xml, value_sets_from_single_code_references)
      @hqmf_xml = hqmf_xml
      @single_code_concepts = map_single_code_concepts(value_sets_from_single_code_references)
    end

    def extract_data_criteria
      data_criteria_entries = @hqmf_xml.css('QualityMeasureDocument/component/dataCriteriaSection/entry')
      source_data_criteria = data_criteria_entries.map { |entry| modelize_data_criteria_entry(entry) }

      # We create the sdc in such a way that "negative" ones look positive in our array by now,
      # so using uniq should give us an array of all positive criteria with no duplicates
      source_data_criteria.uniq!(&:hqmfOid)
      return source_data_criteria
    end

    private

    def modelize_data_criteria_entry(entry)
      criteria = entry.at_xpath('./*[xmlns:templateId/xmlns:item]')
      model_fields =  if entry.at_css('localVariableName').present?
                        extract_fields_from_standard_data_criteria(criteria, entry)
                      else
                        extract_fields_from_single_code_reference_data_criteria(criteria)
                      end
      hqmf_template_oid = criteria.at_css('templateId/item')['root']
      model = QDM::ModelFinder.by_hqmf_oid(hqmf_template_oid).new(model_fields)
      model.description = model.hqmfTitle + ': ' + model.description
      return model
    end

    def extract_fields_from_standard_data_criteria(criteria, entry)
      entry_variable_name_prefix = entry.at_css('localVariableName')['value'].split('_').first
      node_with_valueset = (criteria.at_css('value[valueSet]') || criteria.at_css('code[valueSet]'))
      code_list_id = node_with_valueset.present? ? node_with_valueset['valueSet'] : nil
      return {
        description: entry_variable_name_prefix,
        codeListId: code_list_id
      }
    end

    def extract_fields_from_single_code_reference_data_criteria(criteria)
      single_code_reference = criteria.at_css('code[codeSystem][code]')
      system_id = "#{single_code_reference['codeSystem']}_#{single_code_reference['codeSystemVersion']}".to_sym
      concept = @single_code_concepts[system_id][single_code_reference['code'].to_sym]
      value_set = concept._parent
      return {
        description: concept.display_name,
        codeListId: value_set.oid
      }
    end

    def map_single_code_concepts(value_sets_from_single_code_references)
      single_code_concepts = {}
      value_sets_from_single_code_references.flat_map(&:concepts).each do |concept|
        system_id = "#{concept.code_system_oid}_#{concept.code_system_version.to_s.sub('urn:hl7:version:','')}".to_sym
        single_code_concepts[system_id] ||= {}
        single_code_concepts[system_id][concept.code.to_sym] = concept
      end
      return single_code_concepts
    end
  end
end
