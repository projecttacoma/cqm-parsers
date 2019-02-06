require 'cqm/models'

module Measures
  module HQMFMeasureLoader
    class << self

      def create_measure_model(hqmf_xml, hqmf_model_hash)
        measure = CQM::Measure.new

        measure.measure_attributes = hqmf_model_hash[:attributes]
        measure.main_cql_library = hqmf_model_hash[:cql_measure_library]
        measure.hqmf_id = hqmf_model_hash[:hqmf_id]
        measure.hqmf_set_id = hqmf_model_hash[:hqmf_set_id]
        measure.hqmf_version_number = hqmf_model_hash[:hqmf_version_number]
        measure.cms_id = hqmf_model_hash[:cms_id]
        measure.title = hqmf_model_hash[:title]
        measure.description = hqmf_model_hash[:description]
        measure.measure_period = hqmf_model_hash[:measure_period]
        measure.population_criteria = hqmf_model_hash[:population_criteria]
        measure.source_data_criteria = hqmf_model_hash[:source_data_criteria]
        measure.data_criteria = hqmf_model_hash[:data_criteria]

        measure.measure_scoring = extract_measure_scoring(hqmf_xml)
        measure.population_sets = extract_population_set_models(hqmf_xml, measure.measure_scoring)

        # add observation info
        (hqmf_model_hash[:observations] || []).each do |observation|
          observation = CQM::Observation.new(
            observation_function: CQM::StatementReference.new(
              library_name: hqmf_model_hash[:cql_measure_library],
              statement_name: observation[:function_name]
            ),
            observation_parameter: CQM::StatementReference.new(
              library_name: hqmf_model_hash[:cql_measure_library],
              statement_name: observation[:parameter]
            )
          )
          # add observation to each population set
          measure.population_sets.each { |population_set| population_set.observations << observation }
        end

        return measure
      end

      private

      def extract_measure_scoring(hqmf_xml)
        map_from_hqmf_name_to_full_name = {
          'PROPOR' => 'PROPORTION',
          'RATIO' => 'RATIO',
          'CONTVAR' => 'CONTINUOUS_VARIABLE',
          'COHORT' => 'COHORT'
        }
        scoring = hqmf_xml.at_xpath("/xmlns:QualityMeasureDocument/xmlns:subjectOf/xmlns:measureAttribute[xmlns:code/@code='MSRSCORE']/xmlns:value").attr('code')
        scoring_full_name = map_from_hqmf_name_to_full_name[scoring]
        raise StandardError("Unknown measure scoring type encountered #{scoring}") if scoring_full_name.nil?
        return scoring_full_name
      end

      def extract_population_set_models(hqmf_xml, measure_scoring)
        populations = hqmf_xml.css('/QualityMeasureDocument/component/populationCriteriaSection')
        return populations.map do |population|
          ps_hash = extract_population_set(population)
          population_set = CQM::PopulationSet.new(title: ps_hash[:title], population_set_id: ps_hash[:id])
  
          population_set.populations = construct_population_map(measure_scoring)  
          ps_hash[:populations].each do |pop_code,statement_ref_string|
            population_set.populations[pop_code] = modelize_statement_ref_string(statement_ref_string)
          end
  
          ps_hash[:supplemental_data_elements].each do |statement_ref_string|
            population_set.supplemental_data_elements << modelize_statement_ref_string(statement_ref_string)
          end
          
          ps_hash[:stratifications].each_with_index do |statement_ref_string, index|
            population_set.stratifications << CQM::Stratification.new(
              stratification_id: (index+1).to_s,
              title: "#{population_set.population_set_id}: Stratification #{index+1}",
              statement: modelize_statement_ref_string(statement_ref_string)
            )
          end
          population_set
        end
      end

      def extract_population_set(population_hqmf_node)
        ps = { populations: {}, stratifications: [], supplemental_data_elements: [] }
        ps[:id] = population_hqmf_node.at_css('id').attr('extension')
        ps[:title] = population_hqmf_node.at_css('title').attr('value')
        criteria_components = population_hqmf_node.css('component').flat_map(&:children)
        criteria_components.each do |cc|
          statement_ref = cc.at_css('precondition/criteriaReference/id')
          next if statement_ref.nil?
          statement_ref_string = statement_ref.attr('extension')
          case cc.name
          when 'initialPopulationCriteria'
            ps[:populations][HQMF::PopulationCriteria::IPP] = statement_ref_string
          when 'denominatorCriteria'
            ps[:populations][HQMF::PopulationCriteria::DENOM] = statement_ref_string
          when 'numeratorCriteria'
            ps[:populations][HQMF::PopulationCriteria::NUMER] = statement_ref_string
          when 'numeratorExclusionCriteria'
            ps[:populations][HQMF::PopulationCriteria::NUMEX] = statement_ref_string
          when 'denominatorExclusionCriteria'
            ps[:populations][HQMF::PopulationCriteria::DENEX] = statement_ref_string
          when 'measurePopulationCriteria'
            ps[:populations][HQMF::PopulationCriteria::MSRPOPL] = statement_ref_string
          when 'measurePopulationExclusionCriteria'
            ps[:populations][HQMF::PopulationCriteria::MSRPOPLEX] = statement_ref_string
          when 'stratifierCriteria'
            # Ignore Supplemental Data Elements
            next if cc.at_css('component[@typeCode="COMP"]/measureAttribute/code[@code="SDE"]').present?
            ps[:stratifications] << statement_ref_string
          when 'supplementalDataElement'
            ps[:supplemental_data_elements] << statement_ref_string
          end
        end
        return ps
      end

      def construct_population_map(measure_scoring)
        case measure_scoring
        when 'PROPORTION'
          CQM::ProportionPopulationMap.new
        when 'RATIO'
          CQM::RatioPopulationMap.new
        when 'CONTINUOUS_VARIABLE'
          CQM::ContinuousVariablePopulationMap.new
        when 'COHORT'
          CQM::CohortPopulationMap.new
        else
          raise StandardError("Unknown measure scoring type encountered #{measure_scoring}")
        end
      end
  
      def modelize_statement_ref_string(statement_ref_string)
        library_name, statement_name = statement_ref_string.split('.', 2)
        return CQM::StatementReference.new(
          library_name: library_name,
          statement_name: Utilities.remove_enclosing_quotes(statement_name)
        )
      end

    end
  end
end
