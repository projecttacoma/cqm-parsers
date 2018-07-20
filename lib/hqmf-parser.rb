# require
require 'nokogiri'
require 'json'
require 'ostruct'

# require_relative
require_relative 'util/counter.rb'
require_relative 'util/code_system_helper'
require_relative 'util/hqmf_template_helper'

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

require_relative 'qrda-export/helper/code_system_helper.rb'
require_relative 'qrda-export/helper/date_helper.rb'
require_relative 'qrda-export/helper/cat_1_view_helper.rb'

require_relative 'qrda-export/catI-r5/qrda1_r5.rb'

require_relative 'qrda-import/entry_package.rb'
require_relative 'qrda-import/cda_identifier.rb'
require_relative 'qrda-import/narrative_reference_handler.rb'
require_relative 'qrda-import/entry_finder.rb'

require_relative 'qrda-import/base-importers/section_importer.rb'
require_relative 'qrda-import/base-importers/demographics_importer.rb'
#require_relative 'qrda-import/base-importers/encounter_importer.rb'
require_relative 'qrda-import/base-importers/medication_importer.rb'
#require_relative 'qrda-import/base-importers/procedure_importer.rb'
#require_relative 'qrda-import/base-importers/order_importer.rb'

require_relative 'qrda-import/data-element-importers/allergy_intolerance_importer.rb'
require_relative 'qrda-import/data-element-importers/diagnostic_study_order_importer.rb'
require_relative 'qrda-import/data-element-importers/intervention_order_importer.rb'
require_relative 'qrda-import/data-element-importers/encounter_performed_importer.rb'
require_relative 'qrda-import/data-element-importers/diagnosis_importer.rb'
require_relative 'qrda-import/data-element-importers/medication_active_importer.rb'
require_relative 'qrda-import/data-element-importers/medication_order_importer.rb'
require_relative 'qrda-import/data-element-importers/procedure_performed_importer.rb'
require_relative 'qrda-import/data-element-importers/physical_exam_performed_importer.rb'
require_relative 'qrda-import/data-element-importers/laboratory_test_performed_importer.rb'
require_relative 'qrda-import/data-element-importers/adverse_event_importer.rb'
require_relative 'qrda-import/data-element-importers/assessment_performed_importer.rb'
require_relative 'qrda-import/data-element-importers/communication_from_patient_to_provider_importer.rb'
require_relative 'qrda-import/data-element-importers/communication_from_provider_to_patient_importer.rb'
require_relative 'qrda-import/data-element-importers/communication_from_provider_to_provider_importer.rb'
require_relative 'qrda-import/data-element-importers/device_applied_importer.rb'
require_relative 'qrda-import/data-element-importers/device_order_importer.rb'
require_relative 'qrda-import/data-element-importers/diagnostic_study_performed_importer.rb'
require_relative 'qrda-import/data-element-importers/encounter_order_importer.rb'
require_relative 'qrda-import/data-element-importers/immunization_administered_importer.rb'
require_relative 'qrda-import/data-element-importers/intervention_performed_importer.rb'
require_relative 'qrda-import/data-element-importers/laboratory_test_order_importer.rb'
require_relative 'qrda-import/data-element-importers/medication_administered_importer.rb'
require_relative 'qrda-import/data-element-importers/medication_discharge_importer.rb'
require_relative 'qrda-import/data-element-importers/medication_dispensed_importer.rb'
require_relative 'qrda-import/data-element-importers/patient_characteristic_expired.rb'
require_relative 'qrda-import/data-element-importers/procedure_order_importer.rb'
require_relative 'qrda-import/data-element-importers/substance_administered_importer.rb'
require_relative 'qrda-import/patient_importer.rb'
require_relative 'ext/data_element.rb'
require_relative 'ext/code.rb'
