require 'zip'

module Measures
  class MATMeasureFiles
    attr_accessor :cql_libraries, :human_readable, :components

    FHIR_VERSION = '4.0.1'

    class LogicLibraryContent
      attr_accessor :id, :version, :cql, :elm, :elm_xml
      def initialize(id, version, cql, elm, elm_xml)
        @id = id
        @version = version
        @cql = cql
        @elm = elm
        @elm_xml = elm_xml
      end
    end

    def initialize(cql_libraries, human_readable)
      @cql_libraries = cql_libraries
      @human_readable = human_readable

      raise MeasureLoadingInvalidPackageException.new("Measure package missing required element: Human Readable Document") if @human_readable.nil?
      raise MeasureLoadingInvalidPackageException.new("Measure package missing required element: CQL Libraries") if @cql_libraries.nil? || @cql_libraries.empty?
    end

    def self.create_from_zip_file(zip_file)
      measure_folder = unzip_measure_zip_into_hash(zip_file).values
      raise MeasureLoadingInvalidPackageException.new("No measure found") if measure_folder.empty?
      raise MeasureLoadingInvalidPackageException.new("Multiple measure folders at top level") if measure_folder[0][:depth] == measure_folder.dig(1,:depth)

      measure_assets = measure_folder[0][:files] # make_measure_artifacts(parse_measure_files(measure_folder))

      return measure_assets
    end

    def self.valid_zip?(zip_file)
      create_from_zip_file(zip_file)
      return true
    rescue MeasureLoadingInvalidPackageException
      return false
    end

    def self.parse_lib_contents(library)
      elm_xml, elm, cql, id, version = nil
      library['content'].each do |content|
        case content['contentType']['value']
        when 'application/elm+xml'
          elm_xml = Nokogiri::XML(Base64.decode64(content['data']['value'])) { |config| config.noblanks }
          id, version = get_library_identifier(elm_xml)
        when 'application/elm+json'
          elm = JSON.parse(Base64.decode64(content['data']['value']), max_nesting: 1000)
        when 'text/cql'
          cql = Base64.decode64(content['data']['value'])
          raise MeasureLoadingInvalidPackageException.new("One or more Libraries FHIR version does not match FHIR #{FHIR_VERSION}.") unless cql.to_s.downcase.include? "using FHIR version '#{FHIR_VERSION}'".downcase
        end
      end
      verify_library_versions_match(cql, elm, id, version)
      LogicLibraryContent.new(id,version, cql, elm, elm_xml)
    end

    class << self

      private

      def unzip_measure_zip_into_hash(zip_file)
        folders = Hash.new { |h, k| h[k] = {files: []} }
        Zip::File.open zip_file.path do |file|
          file.each do |f|
            pn = Pathname(f.name)
            next if '__MACOSX'.in? pn.each_filename  # ignore anything in a __MACOSX folder
            next unless pn.basename.extname.in? ['.html','.json']
            folders[pn.dirname][:files] << { basename: pn.basename, contents: f.get_input_stream.read }
            folders[pn.dirname][:depth] =  pn.each_filename.count # this is just a count of how many folders are in the path
          end
        end

        folders
      rescue StandardError
        raise MeasureLoadingInvalidPackageException.new("The uploaded file is not a zip file.")
      end

      def get_library_identifier(elm_annotation)
        identifier = elm_annotation.at_xpath('/xmlns:library/xmlns:identifier')
        id = identifier['id']
        version = identifier['version']
        return id, version
      end

      def verify_library_versions_match(cql, elm, id, version)
        if Helpers.elm_id(elm) != id ||
           Helpers.elm_version(elm) != version ||
           !(cql.include?("library #{id} version '#{version}'") || cql.include?("<library>#{id}</library><version>#{version}</version>"))
          raise MeasureLoadingInvalidPackageException.new("Cql library assets must all have same version.")
        end
      end

    end
  end
end
