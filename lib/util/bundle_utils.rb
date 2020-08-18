module FHIR
  class BundleUtils
    def self.get_measure_bundle(measure_files)
      measure_bundle = measure_files.select {|file| file[:basename].to_s == 'measure-json-bundle.json'}
      raise Measures::MeasureLoadingInvalidPackageException.new("The uploaded measure bundle does not contain the proper FHIR JSON file.") if measure_bundle.empty?
      raise Measures::MeasureLoadingInvalidPackageException.new("Multiple measure bundles were found.") if measure_bundle.length > 1
      begin
        bundle_resource = JSON.parse measure_bundle[0][:contents]
        raise Measures::MeasureLoadingInvalidPackageException.new("The uploaded files do not appear to be in the correct format.") unless bundle_resource['resourceType'] == 'Bundle'
        bundle_resource
      rescue
        raise Measures::MeasureLoadingInvalidPackageException.new("The uploaded files do not appear to be in the correct format.")
      end
    end

    def self.get_resources_by_name(bundle:, name:)
      entries = bundle['entry']
      resources = entries.select { |entry| entry['resource']['resourceType'] == name }
      resources
    end

  end
end
