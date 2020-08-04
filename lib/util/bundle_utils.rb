module FHIR
  class BundleUtils
    def self.get_measure_bundle(measure_files)
      measure_bundle = measure_files.select {|file| file[:basename].to_s == 'measure-json-bundle.json'}
      raise MeasureLoadingInvalidPackageException.new("No measure bundle found") if measure_bundle.empty?
      raise MeasureLoadingInvalidPackageException.new("Multiple measure bundles found") if measure_bundle.length > 1
      bundle_resource = JSON.parse measure_bundle[0][:contents]
      raise MeasureLoadingInvalidPackageException.new("Invalid Measure bundle") unless bundle_resource['resourceType'] == 'Bundle'

      bundle_resource
    end

    def self.get_resources_by_name(bundle:, name:)
      entries = bundle['entry']
      resources = entries.select { |entry| entry['resource']['resourceType'] == name }
      resources
    end

  end
end
