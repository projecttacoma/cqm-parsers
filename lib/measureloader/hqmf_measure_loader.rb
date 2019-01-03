require 'cqm/models'

module Measures
  class HQMFMeasureLoader

    def self.create_measure_model(hqmf_model_hash, measure_scoring)
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

      hqmf_model_hash[:populations].reject{ |p| p.has_key?(:stratification_index) }.each do |population|
        measure.population_sets << convert_population_to_population_set(population, measure_scoring, measure.main_cql_library, hqmf_model_hash[:populations_cql_map])
      end
      hqmf_model_hash[:populations].select{ |p| p.has_key?(:stratification_index) }.each do |stratification|
        cqm_strat = convert_to_cqm_stratification(stratification, hqmf_model_hash[:cql_measure_library], hqmf_model_hash[:populations_cql_map])
        measure.population_sets[bonnie_stratification[:population_index]].stratifications << cqm_strat
      end

      # add observation info
      hqmf_model_hash[:observations].each do |bonnie_observation|
        observation = CQM::Observation.new(
          observation_function: CQM::StatementReference.new(
            library_name: hqmf_model_hash[:cql_measure_library],
            statement_name: bonnie_observation[:function_name]
          )
        )
        # add observation to each population set
        measure.population_sets.each { |population_set| population_set.observations << observation }
      end

      return measure
    end

    private
    def self.convert_to_cqm_stratification(bonnie_stratification, main_cql_library, populations_cql_map)
      return CQM::Stratification.new(
        title: bonnie_stratification[:title],
        id: bonnie_stratification[:id],
        statement: CQM::StatementReference.new(
          library_name: main_cql_library,
          statement_name: get_cql_statement_for_population_key(populations_cql_map, bonnie_stratification[:STRAT])
        )
      )
    end

    private
    def self.convert_population_to_population_set(bonnie_population, measure_scoring, main_cql_library, populations_cql_map)
      population_set = CQM::PopulationSet.new(
        title: bonnie_population[:title],
        id: bonnie_population[:id]
      )
      
      # construct the population map and fill it
      population_map = construct_population_map(measure_scoring)
      bonnie_population.each_pair do |population_name, population_key|
        # make sure it isnt metadata or an OBSERV or SDE list
        if ![:id, :title, :OBSERV, :supplemental_data_elements].include?(population_name)
          population_map[population_name] = CQM::StatementReference.new(
            library_name: main_cql_library,
            statement_name: get_cql_statement_for_population_key(populations_cql_map, population_key)
          )
        end
      end

      population_set.populations = population_map

      # add SDEs
      if bonnie_population.key?('supplemental_data_elements')
        bonnie_population['supplemental_data_elements'].each do |sde_statement|
          population_set.supplemental_data_elements << CQM::StatementReference.new(
            library_name: main_cql_library,
            statement_name: sde_statement
          )
        end
      end

      return population_set
    end

    private
    def self.construct_population_map(measure_scoring)
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

    private
    def self.get_cql_statement_for_population_key(populations_cql_map, population_key)
      if population_key.include?('_')
        pop_name, pop_index = population_key.split('_')
        pop_index = pop_index.to_i
      else
        pop_name = population_key
        pop_index = 0
      end

      populations_cql_map[pop_name.to_sym][pop_index]
    end

  end
end
