require 'cqm/models'

module Measures
  module HQMFMeasureLoader
    class << self

      def extract_fields(hqmf_xml)
        qmd = hqmf_xml.at_css('/QualityMeasureDocument')
        hqmf_id = qmd.at_css('/id')['root'].upcase
        hqmf_set_id = qmd.at_css('/setId')['root'].upcase
        title = qmd.at_css('/title')['value']
        description = qmd.at_css('/text')['value']
        cms_identifier = extract_cms_identifier(qmd)
        hqmf_version_number = qmd.at_css('/versionNumber')['value']
        cms_id = "CMS#{cms_identifier}v#{hqmf_version_number.to_i}"
        main_cql_library = qmd.at_css('/component/populationCriteriaSection/component/initialPopulationCriteria/*/*/id')['extension'].split('.').first
        measure_scoring = extract_measure_scoring(qmd)
        population_sets = extract_population_set_models(qmd, measure_scoring)

        return {
          hqmf_id: hqmf_id,
          hqmf_set_id: hqmf_set_id,
          title: title,
          description: description,
          main_cql_library: main_cql_library,
          hqmf_version_number: hqmf_version_number,
          cms_id: cms_id,
          measure_scoring: measure_scoring,
          population_sets: population_sets
        }
      end

      def add_fields_from_hqmf_model_hash(measure, hqmf_model_hash)
        measure.measure_attributes = hqmf_model_hash[:attributes]
        measure.measure_period = hqmf_model_hash[:measure_period]
        measure.population_criteria = hqmf_model_hash[:population_criteria]

        # add observation info, note population_sets needs to have been added to the measure by now
        (hqmf_model_hash[:observations] || []).each do |observation|
          observation = CQM::Observation.new(
            hqmf_id: observation[:function_hqmf_oid],
            aggregation_type: observation[:function_aggregation_type],
            observation_function: CQM::StatementReference.new(
              library_name: hqmf_model_hash[:cql_measure_library],
              statement_name: observation[:function_name],
              hqmf_id: observation[:function_hqmf_oid]
            ),
            observation_parameter: CQM::StatementReference.new(
              library_name: hqmf_model_hash[:cql_measure_library],
              statement_name: observation[:parameter],
              hqmf_id: observation[:function_hqmf_oid]
            )
          )
          # add observation to each population set
          measure.population_sets.each { |population_set| population_set.observations << observation }
        end
      end

      private

      def extract_cms_identifier(qmd)
        cms_identifier =
          (qmd.at_xpath('./xmlns:subjectOf/xmlns:measureAttribute[xmlns:code/xmlns:originalText[@value="eCQM Identifier (Measure Authoring Tool)"]]/xmlns:value') ||
          qmd.at_xpath('./xmlns:subjectOf/xmlns:measureAttribute[xmlns:code/xmlns:originalText[@value="eMeasure Identifier (Measure Authoring Tool)"]]/xmlns:value'))
        return cms_identifier['value']
      end

      def extract_measure_scoring(qmd)
        map_from_hqmf_name_to_full_name = {
          'PROPOR' => 'PROPORTION',
          'RATIO' => 'RATIO',
          'CONTVAR' => 'CONTINUOUS_VARIABLE',
          'COHORT' => 'COHORT'
        }
        scoring = qmd.at_xpath("./xmlns:subjectOf/xmlns:measureAttribute[xmlns:code/@code='MSRSCORE']/xmlns:value").attr('code')
        scoring_full_name = map_from_hqmf_name_to_full_name[scoring]
        raise StandardError.new("Unknown measure scoring type encountered #{scoring}") if scoring_full_name.nil?
        return scoring_full_name
      end

      def extract_population_set_models(qmd, measure_scoring)
        populations = qmd.css('/component/populationCriteriaSection')
        return populations.map.with_index do |population, pop_index|
          ps_hash = extract_population_set(population)
          population_set = CQM::PopulationSet.new(
            title: ps_hash[:title],
            population_set_id: "PopulationSet_#{pop_index+1}"
          )

          population_set.populations = construct_population_map(measure_scoring)
          ps_hash[:populations].each do |pop_code,statement_ref_hash|
            population_set.populations[pop_code] = CQM::StatementReference.new(statement_ref_hash)
          end

          ps_hash[:supplemental_data_elements].each do |statement_ref_hash|
            population_set.supplemental_data_elements << CQM::StatementReference.new(statement_ref_hash)
          end

          ps_hash[:stratifications].each_with_index do |statement_ref_hash, index|
            population_set.stratifications << CQM::Stratification.new(
              hqmf_id: statement_ref_hash[:hqmf_id],
              stratification_id: "#{population_set.population_set_id}_Stratification_#{index+1}",
              title: "PopSet#{pop_index+1} Stratification #{index+1}",
              statement: CQM::StatementReference.new(statement_ref_hash)
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
          subject_ref = cc.at_css('subject/criteriaReference/id')
          subject_hqmf_id = subject_ref.nil? ? nil : subject_ref.attr('root')
          next if statement_ref.nil?
          statement_ref_hash = { library_name: statement_ref.attr('extension').split('.')[0],
                                 statement_name: Utilities.remove_enclosing_quotes(statement_ref.attr('extension').split('.')[1]),
                                 hqmf_id: cc.at_css('id').attr('root'),
                                 subject_id: subject_hqmf_id }
          case cc.name
          when 'initialPopulationCriteria'
            if ps[:populations][HQMF::PopulationCriteria::IPP].nil?
              ps[:populations][HQMF::PopulationCriteria::IPP] = statement_ref_hash
            else
              ps[:populations][HQMF::PopulationCriteria::IPP_1] = statement_ref_hash
            end
          when 'denominatorCriteria'
            ps[:populations][HQMF::PopulationCriteria::DENOM] = statement_ref_hash
          when 'numeratorCriteria'
            ps[:populations][HQMF::PopulationCriteria::NUMER] = statement_ref_hash
          when 'numeratorExclusionCriteria'
            ps[:populations][HQMF::PopulationCriteria::NUMEX] = statement_ref_hash
          when 'denominatorExclusionCriteria'
            ps[:populations][HQMF::PopulationCriteria::DENEX] = statement_ref_hash
          when 'denominatorExceptionCriteria'
            ps[:populations][HQMF::PopulationCriteria::DENEXCEP] = statement_ref_hash
          when 'measurePopulationCriteria'
            ps[:populations][HQMF::PopulationCriteria::MSRPOPL] = statement_ref_hash
          when 'measurePopulationExclusionCriteria'
            ps[:populations][HQMF::PopulationCriteria::MSRPOPLEX] = statement_ref_hash
          when 'stratifierCriteria'
            # Ignore Supplemental Data Elements
            next if holds_supplemental_data_elements(cc)
            ps[:stratifications] << statement_ref_hash
          when 'supplementalDataElement'
            ps[:supplemental_data_elements] << statement_ref_hash
          end
        end
        return ps
      end

      def holds_supplemental_data_elements(criteria_component_node)
        return criteria_component_node.at_css('component[@typeCode="COMP"]/measureAttribute/code[@code="SDE"]').present?
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
          raise StandardError.new("Unknown measure scoring type encountered #{measure_scoring}")
        end
      end
    end
  end
end
