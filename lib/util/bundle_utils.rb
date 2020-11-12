module FHIR
  class BundleUtils
    def self.get_measure_bundle(measure_files)
      measure_bundle = measure_files.select {|file| file[:basename].to_s == 'measure-json-bundle.json'}
      raise Measures::MeasureLoadingInvalidPackageException.new("The uploaded measure bundle does not contain the proper FHIR JSON file.") if measure_bundle.empty?
      raise Measures::MeasureLoadingInvalidPackageException.new("Multiple measure bundles were found.") if measure_bundle.length > 1

      bundle_resource = JSON.parse measure_bundle[0][:contents]
      raise Measures::MeasureLoadingInvalidPackageException.new("The uploaded files do not appear to be in the correct format.") unless bundle_resource['resourceType'] == 'Bundle'
      bundle_resource
    rescue JSON::ParserError
      raise Measures::MeasureLoadingInvalidPackageException.new("The uploaded files do not appear to be in the correct format.")
    end

    def self.get_resources_by_name(bundle:, name:)
      entries = bundle['entry']
      resources = entries.select { |entry| entry['resource']['resourceType'] == name }
      resources
    end

    def self.get_measurement_period(fhir_measure)
      mp = {}
      if fhir_measure.effectivePeriod
        mp[:start] = fhir_measure.effectivePeriod.start&.value
        mp[:end] = fhir_measure.effectivePeriod.end&.value
      else
        # Default measurement period
        mp[:start] = '2019-01-01'
        mp[:end] = '2019-12-31'
      end
      mp
    end
  end
end
