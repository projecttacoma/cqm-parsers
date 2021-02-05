module FHIR
  class BundleUtils
    def self.get_measure_bundle(measure_files)
      measure_bundle = measure_files.select {|file| file[:basename].to_s.end_with?('json')}
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
      mp[:start] =
        if fhir_measure.effectivePeriod.start&.value
          fhir_measure.effectivePeriod.start.value << "T00:00:00"
        else
          # Default measurement period start
          '2019-01-01T00:00:00'
        end
      mp[:end] =
        if fhir_measure.effectivePeriod.end&.value
          fhir_measure.effectivePeriod.end.value << "T23:59:59"
        else
          # Default measurement period end
          mp[:end] = '2019-12-31T23:59:59'
        end
      mp
    end
  end
end
