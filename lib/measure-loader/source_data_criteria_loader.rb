module Measures
  class SourceDataCriteriaLoader

    def initialize(hqmf_xml, value_sets_from_single_code_references)
      @hqmf_xml = hqmf_xml
      @single_code_concepts = map_single_code_concepts(value_sets_from_single_code_references)
    end

    def extract_data_criteria()
      data_criteria_entries = @hqmf_xml.css('QualityMeasureDocument/component/dataCriteriaSection/entry')
      source_data_criteria = data_criteria_entries.map do |entry|
        criteria = entry.at_xpath("./*[xmlns:templateId/xmlns:item]")
        hqmf_template_oid = criteria.at_css('templateId/item')['root']
        model_fields = entry.at_css('localVariableName').present? ?
          model_fields_for_data_criteria(criteria, entry) :
          model_fields_for_single_code_reference_data_criteria(criteria)
        model = QDM::ModelFinder.byHqmfOid(hqmf_template_oid).new(model_fields)
        model.description = model.hqmfTitle + ": " + model.description
        model
      end
      # We create the sdc in such a way that "negative" ones look positive in our array by now,
      # so using uniq should give us an array of all positive criteria with no duplicates
      source_data_criteria.uniq!{ |sdc| sdc.hqmfOid }
      return source_data_criteria
    end

    private

    def model_fields_for_data_criteria(criteria, entry)
      entry_variable_name_prefix = entry.at_css('localVariableName')['value'].split('_').first
      return {
        description: "#{entry_variable_name_prefix}",
        codeListId: (criteria.at_css('value[valueSet]') || criteria.at_css('code[valueSet]'))['valueSet']
      }
    end

    def model_fields_for_single_code_reference_data_criteria(criteria)
      single_code_reference = criteria.at_css('code[codeSystem][codeSystemVersion][code]')
      system_id = "#{single_code_reference["codeSystem"]}_#{single_code_reference["codeSystemVersion"]}".to_sym
      concept = @single_code_concepts[system_id][single_code_reference["code"].to_sym]
      value_set = concept._parent
      return {
        description: "#{concept.display_name}",
        codeListId: value_set.oid
      }
    end

    def criteria_title(criteria)
      "#{criteria.at_css('title')['value']}"
      @description.gsub!(', Not', ',') #eg "Procedure, Not Performed"
    end

    def map_single_code_concepts(value_sets_from_single_code_references)
      single_code_concepts = {}
      value_sets_from_single_code_references.flat_map(&:concepts).each do |concept|
        system_id = "#{concept.code_system_oid}_#{concept.code_system_version.sub("urn:hl7:version:","")}".to_sym
        single_code_concepts[system_id] ||= {}
        single_code_concepts[system_id][concept.code.to_sym] = concept
      end
      return single_code_concepts
    end

  end
end