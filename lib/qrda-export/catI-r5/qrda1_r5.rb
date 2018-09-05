require 'mustache'
class Qrda1R5 < Mustache
  include Qrda::Export::Helper::DateHelper
  include Qrda::Export::Helper::ViewHelper
  include Qrda::Export::Helper::Cat1ViewHelper
  include Qrda::Export::Helper::PatientViewHelper

  self.template_path = __dir__

  def initialize(patient, measures, options = {})
    @patient = patient
    @measures = measures
    @provider = options[:provider]
    @performance_period_start = options[:start_time]
    @performance_period_end = options[:end_time]
    @submission_program = options[:submission_program]
    @insurance_provider = JSON.parse(@patient.extendedData.insurance_providers) if @patient.extendedData && @patient.extendedData['insurance_providers']
  end

  def adverse_event
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.120').to_json)
  end

  def allergy_intolerance
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.119').to_json)
  end

  def assessment_performed
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.117').to_json)
  end

  def communication_from_patient_to_provider
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.3.560.1.30').to_json)
  end

  def communication_from_provider_to_patient
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.31','2.16.840.1.113883.3.560.1.131'] }).to_json)
  end

  def communication_from_provider_to_provider
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.29','2.16.840.1.113883.3.560.1.129'] }).to_json)
  end

  def diagnosis
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.110').to_json)
  end

  def device_ordered
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.37','2.16.840.1.113883.3.560.1.137'] }).to_json)
  end

  def device_applied
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.10','2.16.840.1.113883.3.560.1.110'] }).to_json)
  end

  def diagnostic_study_ordered
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.40','2.16.840.1.113883.3.560.1.140'] }).to_json)
  end

  def diagnostic_study_performed
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.103','2.16.840.1.113883.3.560.1.3'] }).to_json)
  end

  def encounter_ordered
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.3.560.1.83').to_json)
  end

  def encounter_performed
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.3.560.1.79').to_json)
  end

  def immunization_aministered
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.10.20.28.3.112'] }).to_json)
  end

  def intervention_ordered
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.45','2.16.840.1.113883.3.560.1.145'] }).to_json)
  end

  def intervention_performed
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.46','2.16.840.1.113883.3.560.1.146'] }).to_json)
  end

  def lab_test_performed
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.3.560.1.5').to_json)
  end

  def lab_test_ordered
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.50','2.16.840.1.113883.3.560.1.150'] }).to_json)
  end

  def medication_active
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.3.560.1.13').to_json)
  end

  def medication_administered
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.14','2.16.840.1.113883.3.560.1.64','2.16.840.1.113883.3.560.1.114'] }).to_json)
  end

  def medication_discharge
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.199','2.16.840.1.113883.3.560.1.200'] }).to_json)
  end

  def medication_dispensed
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.3.560.1.8').to_json)
  end

  def medication_ordered
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.78','2.16.840.1.113883.3.560.1.17'] }).to_json)
  end

  def patient_characteristic_expired
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.10.20.28.3.57').to_json)
  end
  
  def physical_exam_performed
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.57','2.16.840.1.113883.3.560.1.157'] }).to_json)
  end

  def procedure_ordered
    JSON.parse(@patient.dataElements.where(hqmfOid: '2.16.840.1.113883.3.560.1.62').to_json)
  end

  def procedure_performed
    JSON.parse(@patient.dataElements.where(hqmfOid: { '$in' => ['2.16.840.1.113883.3.560.1.6','2.16.840.1.113883.3.560.1.106'] }).to_json)
  end
end
