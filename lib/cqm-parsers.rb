# require
require 'nokogiri'
require 'json'
require 'ostruct'
require 'fhir/mongoid/models'

# require_relative
require_relative 'util/counter.rb'
require_relative 'util/code_system_helper'
require_relative 'util/hqmf_template_helper'
require_relative 'util/vsac_api'
require_relative 'util/util'

require_relative 'hqmf-model/utilities.rb'

require_relative 'hqmf-parser/1.0/utilities'
require_relative 'hqmf-parser/1.0/range'
require_relative 'hqmf-parser/1.0/document'
require_relative 'hqmf-parser/1.0/data_criteria'
require_relative 'hqmf-parser/1.0/attribute'
require_relative 'hqmf-parser/1.0/population_criteria'
require_relative 'hqmf-parser/1.0/observation'
require_relative 'hqmf-parser/1.0/precondition'
require_relative 'hqmf-parser/1.0/restriction'
require_relative 'hqmf-parser/1.0/comparison'
require_relative 'hqmf-parser/1.0/expression'

require_relative 'hqmf-parser/2.0/utilities'
require_relative 'hqmf-parser/2.0/types'
require_relative 'hqmf-parser/2.0/document_helpers/doc_population_helper'
require_relative 'hqmf-parser/2.0/document_helpers/doc_utilities'
require_relative 'hqmf-parser/2.0/document'
require_relative 'hqmf-parser/2.0/field_value_helper'
require_relative 'hqmf-parser/2.0/value_set_helper'
require_relative 'hqmf-parser/2.0/source_data_criteria_helper'
require_relative 'hqmf-parser/2.0/data_criteria_helpers/dc_definition_from_template_or_type_extract'
require_relative 'hqmf-parser/2.0/data_criteria_helpers/dc_specific_occurrences_and_source_data_criteria_extract'
require_relative 'hqmf-parser/2.0/data_criteria_helpers/dc_post_processing'
require_relative 'hqmf-parser/2.0/data_criteria_helpers/dc_base_extract'
require_relative 'hqmf-parser/2.0/data_criteria'
require_relative 'hqmf-parser/2.0/population_criteria'
require_relative 'hqmf-parser/2.0/precondition'

require_relative 'hqmf-parser/cql/document'
require_relative 'hqmf-parser/cql/data_criteria_helpers/dc_definition_from_template_or_type_extract'
require_relative 'hqmf-parser/cql/document_helpers/doc_population_helper'
require_relative 'hqmf-parser/cql/data_criteria_helpers/dc_post_processing'
require_relative 'hqmf-parser/cql/data_criteria'
require_relative 'hqmf-parser/cql/value_set_helper'

require_relative 'hqmf-model/data_criteria.rb'
require_relative 'hqmf-model/document.rb'
require_relative 'hqmf-model/population_criteria.rb'
require_relative 'hqmf-model/precondition.rb'
require_relative 'hqmf-model/types.rb'
require_relative 'hqmf-model/attribute.rb'

require_relative 'hqmf-parser/converter/pass1/document_converter'
require_relative 'hqmf-parser/converter/pass1/data_criteria_converter'
require_relative 'hqmf-parser/converter/pass1/population_criteria_converter'
require_relative 'hqmf-parser/converter/pass1/precondition_converter'
require_relative 'hqmf-parser/converter/pass1/precondition_extractor'
require_relative 'hqmf-parser/converter/pass1/simple_restriction'
require_relative 'hqmf-parser/converter/pass1/simple_operator'
require_relative 'hqmf-parser/converter/pass1/simple_precondition'
require_relative 'hqmf-parser/converter/pass1/simple_data_criteria'
require_relative 'hqmf-parser/converter/pass1/simple_population_criteria'

require_relative 'hqmf-parser/converter/pass2/comparison_converter'
require_relative 'hqmf-parser/converter/pass2/operator_converter'

require_relative 'hqmf-parser/parser'

require_relative 'ext/data_element.rb'

require_relative 'measure-loader/helpers'
require_relative 'measure-loader/cql_loader'
require_relative 'measure-loader/elm_dependency_finder'
require_relative 'measure-loader/elm_parser'
require_relative 'measure-loader/exceptions'
# require_relative 'measure-loader/hqmf_measure_loader'
require_relative 'measure-loader/mat_measure_files'
require_relative 'measure-loader/source_data_criteria_loader'
require_relative 'measure-loader/value_set_helpers'
require_relative 'measure-loader/vsac_value_set_loader'
