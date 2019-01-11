require 'zip'

module Measures
  class MATMeasureFiles
    attr_accessor :hqmf_xml, :cql_libraries, :human_readable, :components

    class CqlLibraryFiles
      attr_accessor :id, :version, :cql, :elm, :elm_xml
      def initialize(id, version, cql, elm, elm_xml)
        @id = id
        @version = version
        @cql = cql
        @elm = elm
        @elm_xml = elm_xml
      end
    end

    def initialize(hqmf_xml, cql_libraries, human_readable)
      @hqmf_xml = hqmf_xml
      @cql_libraries = cql_libraries
      @human_readable = human_readable
      
      raise MeasureLoadingException.new("Measure package missing required element: HQMF XML File") if @hqmf_xml.nil?
      raise MeasureLoadingException.new("Measure package missing required element: Human Readable Document") if @human_readable.nil?
      raise MeasureLoadingException.new("Measure package missing required element: CQL Libraries") if @cql_libraries.nil? || @cql_libraries.empty?
    end

    def self.create_from_zip_file(zip_file)
      folders = unzip_measure_zip_into_hash(zip_file).values
      raise MeasureLoadingException.new("No measure found") if folders.empty?
      folders.sort_by! { |h| h[:depth] }
      raise MeasureLoadingException.new("Multiple measure folders at top level") if folders[0][:depth] == folders.dig(1,:depth)
      
      measure_folder, *component_measure_folders = folders
      measure_assets = make_measure_artifacts(parse_measure_files(measure_folder))
      measure_assets.components = component_measure_folders.collect {|f| make_measure_artifacts(parse_measure_files(f))}

      return measure_assets
    end

    def self.valid_zip?(zip_file)
      create_from_zip_file(zip_file)
      return true
    rescue StandardError
      return false
    end

    class << self

      private

      def unzip_measure_zip_into_hash(zip_file)
        folders = Hash.new { |h, k| h[k] = {files: []} }
        Zip::File.open zip_file do |file|
          file.each do |f|
            pn = Pathname(f.name)
            next if '__MACOSX'.in? pn.each_filename  # ignore anything in a __MACOSX folder
            next unless pn.basename.extname.in? ['.xml','.cql','.json','.html']
            folders[pn.dirname][:files] << { basename: pn.basename, contents: f.get_input_stream.read }
            folders[pn.dirname][:depth] =  pn.each_filename.count # this is just a count of how many folders are in the path
          end
        end
        return folders
      end

      def make_measure_artifacts(measure_files)
        library_count = measure_files[:cqls].length
        unless (measure_files[:elm_xmls].length == library_count && measure_files[:elms].length == library_count)
          raise MeasureLoadingException.new("Each library must have a CQL file, an ELM JSON file, and an ELM XML file.")
        end

        cql_libraries = []
        library_count.times do |i|
          elm_annotation = measure_files[:elm_xmls][i]
          elm = measure_files[:elms][i]
          cql = measure_files[:cqls][i]

          id, version = verify_library_versions_match_and_get_version(cql, elm, elm_annotation)
          cql_libraries << CqlLibraryFiles.new(id, version, cql, elm, elm_annotation)
        end

        return new(measure_files[:hqmf_xml], cql_libraries, measure_files[:human_readable])
      end

      def parse_measure_files(folder)
        measure_files = { cqls: [], elms: [], elm_xmls: [] }
        folder[:files].sort_by! { |h| h[:basename] }
        folder[:files].each do |file|
          case file[:basename].extname.to_s
          when '.cql'
            measure_files[:cqls] << file[:contents]
          when '.json'
            begin
              measure_files[:elms] << JSON.parse(file[:contents], max_nesting: 1000)
            rescue StandardError
              raise MeasureLoadingException.new("Unable to parse json file #{basename}")
            end
          when '.html'
            raise MeasureLoadingException.new("Multiple HumanReadable docs found in same folder") unless measure_files[:human_readable].nil?
            measure_files[:human_readable] = file[:contents]
          when '.xml'
            begin
              doc = Nokogiri::XML(file[:contents]) { |config| config.noblanks }
            rescue StandardError
              raise MeasureLoadingException.new("Unable to parse xml file #{basename}")
            end
            if doc.root.name == 'QualityMeasureDocument'
              raise MeasureLoadingException.new("Multiple QualityMeasureDocuments found in same folder") unless measure_files[:hqmf_xml].nil?
              measure_files[:hqmf_xml] = doc
            elsif doc.root.name == 'library'
              measure_files[:elm_xmls] << doc
            end
          end
        end
        raise MeasureLoadingException.new("Measure folder found with no hqmf") if measure_files[:hqmf_xml].nil?
        return measure_files
      end

      def verify_library_versions_match_and_get_version(cql, elm, elm_annotation)
        identifier = elm_annotation.at_xpath('/xmlns:library/xmlns:identifier')
        id = identifier['id']
        version = identifier['version']

        if (Helpers.elm_id(elm)!= id ||
            Helpers.elm_version(elm) != version ||
            !(cql.include?("library #{id} version '#{version}'") || cql.include?("<library>#{id}</library><version>#{version}</version>"))
           )
          raise MeasureLoadingException.new("Cql library assets must all have same version.")
        end

        return id, version
      end

    end
  end
end