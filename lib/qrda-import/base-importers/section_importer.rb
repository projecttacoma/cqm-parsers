module QRDA
  module Cat1
    class SectionImporter
      attr_accessor :check_for_usable, :status_xpath, :code_xpath

      def initialize(entry_finder)
        @entry_finder = entry_finder
        @code_xpath = "./cda:code"
        @id_xpath = "./cda:id"
        #@status_xpath = nil
        #@priority_xpath = nil
        #@description_xpath = "./cda:code/cda:originalText/cda:reference[@value] | ./cda:text/cda:reference[@value]"
        @check_for_usable = true
        @entry_class = QDM::DataElement
      end

      # Traverses an HL7 CDA document passed in and creates an Array of Entry
      # objects based on what it finds
      # @param [Nokogiri::XML::Document] doc It is expected that the root node of this document
      #        will have the "cda" namespace registered to "urn:hl7-org:v3"
      #        measure definition
      # @return [Array] will be a list of Entry objects
      def create_entries(doc, nrh = NarrativeReferenceHandler.new)
        entry_list = []
        entry_elements = @entry_finder.entries(doc)
        entry_elements.each do |entry_element|
          entry = create_entry(entry_element, nrh)
          if @check_for_usable
            entry_list << entry if usable_entry?(entry)
          else
            entry_list << entry
          end
        end
        entry_list
      end

      def usable_entry?(entry)
        entry.dataElementCodes.present?
      end

      def create_entry(entry_element, nrh = NarrativeReferenceHandler.new)
        entry = @entry_class.new
        #extract_id(entry_element, entry)
        entry.dataElementCodes = extract_codes(entry_element, @code_xpath)
        extract_dates(entry_element, entry)
        if @result_xpath
          entry.result = extract_result_values(entry_element)
        end
        extract_reason_or_negation(entry_element, entry)
        # extract_description(entry_element, entry, nrh)
        # if @status_xpath
        #   extract_status(entry_element, entry)
        # end
        entry
      end

      private

      def extract_description(parent_element, entry, nrh)
        # orig_text_ref_element = parent_element.at_xpath(@description_xpath)
        # desc_ref_element = parent_element.at_xpath("./cda:text/cda:reference")
        # if orig_text_ref_element && orig_text_ref_element['value']
        #   entry.description = nrh.lookup_tag(orig_text_ref_element['value'])
        # elsif desc_ref_element && desc_ref_element['value']
        #   entry.description = nrh.lookup_tag(desc_ref_element['value'])
        # else
        #   entry.description = parent_element.at_xpath("./cda:text").try("text")
        # end
      end

      def extract_status(parent_element, entry)
        # status_element = parent_element.at_xpath(@status_xpath)
        # if status_element
        #   entry.status_code = {HQMF::Util::CodeSystemHelper.code_system_for(status_element['codeSystem']) => [status_element['code']]}
        # end
      end

      def extract_id(parent_element, entry)
        # id_element = parent_element.at_xpath(@id_xpath)
        # if id_element
        #   identifier = CDAIdentifier.new
        #   identifier.root = id_element['root']
        #   identifier.extension = id_element['extension']
        #   entry['cda_identifier'] = identifier
        # end
      end

      def extract_reason_description(parent_element, entry, nrh)
        # code_elements = parent_element.xpath(@description_xpath)
        # code_elements.each do |code_element|
        #   tag = code_element['value']
        #   entry.description = nrh.lookup_tag(tag)
        # end
      end

      def extract_codes(coded_element, code_xpath)
        code_list = []
        code_elements = coded_element.xpath(code_xpath)
        code_elements.each do |code_element|
          code_list << code_if_present(code_element)
          translations = code_element.xpath('cda:translation')
          translations.each do |translation|
            code_list << code_if_present(translation)
          end
        end
        code_list.compact
      end

      def code_if_present(code_element)
        if code_element && code_element['codeSystem'] && code_element['code']
          QDM::Code.new(code_element['code'], HQMF::Util::CodeSystemHelper.code_system_for(code_element['codeSystem']))
        else
          nil
        end
      end


      def extract_dates(parent_element, entry)
        entry.authorDatetime = extract_time(parent_element, @author_datetime_xpath) if @author_datetime_xpath
        entry.relevantPeriod = extract_interval(parent_element, @relevant_period_xpath) if @relevant_period_xpath
        entry.prevalencePeriod = extract_interval(parent_element, @prevalence_period_xpath) if @prevalence_period_xpath
      end

      def extract_interval(parent_element, interval_xpath)
        if parent_element.at_xpath("#{interval_xpath}/@value")
          low_time = DateTime.parse(parent_element.at_xpath("#{interval_xpath}")['value'])
          high_time = DateTime.parse(parent_element.at_xpath("#{interval_xpath}")['value'])
        end
        if parent_element.at_xpath("#{interval_xpath}/cda:low")
          low_time = DateTime.parse(parent_element.at_xpath("#{interval_xpath}/cda:low")['value'])
        end
        if parent_element.at_xpath("#{interval_xpath}/cda:high")
          if parent_element.at_xpath("#{interval_xpath}/cda:high")['value']
            high_time = DateTime.parse(parent_element.at_xpath("#{interval_xpath}/cda:high")['value'])
          else
            high_time = DateTime.new(9999,1,1)
          end
        end
        if parent_element.at_xpath("#{interval_xpath}/cda:center")
          low_time = DateTime.parse(parent_element.at_xpath("#{interval_xpath}/cda:center")['value'])
          high_time = DateTime.parse(parent_element.at_xpath("#{interval_xpath}/cda:center")['value'])
        end
        QDM::Interval.new(low_time, high_time).shift_dates(0)
      end

      def extract_time(parent_element, datetime_xpath)
        DateTime.parse(parent_element.at_xpath("#{datetime_xpath}")['value']) if parent_element.at_xpath("#{datetime_xpath}/@value")
      end

      def extract_result_values(parent_element)
        result = []
        parent_element.xpath(@result_xpath).each do |elem|
          result << extract_result_value(elem)
        end
        result.size > 1 ? result : result.first 
      end

      def extract_result_value(value_element)
        if value_element && !value_element['nullFlavor']
          value = value_element['value']
          if value.present?
            return value.strip.to_i if (value_element['unit'] == "1" || value_element['unit'].nil?)
            return QDM::Quantity.new(value.strip.to_i, value_element['unit'])
          elsif value_element['code'].present?
            return code_if_present(value_element)
          else
            # value = value_element.text
            # unit = value_element['unit']
            # entry.set_value(value.strip, unit)
          end
        end
      end

      def import_actor(actor_element)
        # return ProviderImporter.instance.extract_provider(actor_element)
      end

      def import_organization(organization_element)
        # return OrganizationImporter.instance.extract_organization(organization_element)
      end

      def import_person(person_element)
        # return unless person_element
        # person = Person.new
        # name_element = person_element.at_xpath("./cda:name")
        # if name_element
        #   person.title = name_element.at_xpath("./cda:title").try(:text)
        #   person.given_name = name_element.at_xpath("./cda:given").try(:text)
        #   person.family_name = name_element.at_xpath("./cda:family").try(:text)
        # end
        # person.addresses = person_element.xpath("./cda:addr").map { |addr| import_address(addr) }
        # person.telecoms = person_element.xpath("./cda:telecom").map { |tele| import_telecom(tele) }
        # return person
      end

      # extracts the reason or negation data. if an element is negated and the code has a null flavor, a random code is assigned for calculation
      # coded_parent_element is the 'parent' element when the coded is nested (e.g., medication order)
      def extract_reason_or_negation(parent_element, entry, coded_parent_element = nil)
        coded_parent_element ||= parent_element
        reason_element = parent_element.at_xpath("./cda:entryRelationship[@typeCode='RSON']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.88']/cda:value | ./cda:entryRelationship[@typeCode='RSON']/cda:act[cda:templateId/@root='2.16.840.1.113883.10.20.1.27']/cda:code")
        negation_indicator = parent_element['negationInd']
        if reason_element
          code_system_oid = reason_element['codeSystem']
          code = reason_element['code']
          code_system = HQMF::Util::CodeSystemHelper.code_system_for(code_system_oid)
          #entry.negation_ind = negation_indicator.eql?('true')
          if negation_indicator.eql?('true')
            entry.negationRationale = code_if_present(reason_element)
          else
            entry.reason = code_if_present(reason_element)
          end
        end
        extract_negated_code(coded_parent_element, entry)
      end

      def extract_negated_code(coded_parent_element, entry)
        code_elements = coded_parent_element.xpath(@code_xpath)
        code_elements.each do |code_element|
          if code_element['nullFlavor'] == 'NA' && code_element['sdtc:valueSet']
            entry.dataElementCodes = [{ code: code_element['sdtc:valueSet'], codeSystem: 'NA_VALUESET' }]
          end
        end
      end

      def extract_code(parent_element, code_xpath, code_system=nil)
        # code_element = parent_element.at_xpath(code_xpath)
        # code_hash = nil
        # if code_element
        #   code_hash = {'code' => code_element['code']}
        #   if code_system
        #     code_hash['codeSystem'] = code_system
        #   else
        #     code_hash['codeSystemOid'] = code_element['codeSystem']
        #     code_hash['codeSystem'] = HQMF::Util::CodeSystemHelper.code_system_for(code_hash['codeSystemOid'])
        #   end
        # end

        # code_hash
      end

      def extract_scalar(parent_element, scalar_xpath)
        scalar_element = parent_element.at_xpath(scalar_xpath)
        if scalar_element
          QDM::Quantity.new(scalar_element['value'].to_i, scalar_element['unit'])
        else
          nil
        end
      end

      def extract_components(parent_element)
        component_elements = parent_element.xpath(@components_xpath)
        components = []
        if component_elements
          
          component_elements.each do |component_element|
            component = QDM::Component.new
            component.code = code_if_present(component_element.at_xpath('./cda:code'))
            component.result = extract_result_value(component_element.at_xpath('./cda:value'))
            components << component
          end
        end
        components
      end

      def extract_facility(parent_element, entry)
        facility_element = parent_element.at_xpath(@facility_xpath)
        if (facility_element)
          facility = QDM::FacilityLocation.new
          participant_element = facility_element.at_xpath("./cda:participantRole[@classCode='SDLOC']/cda:code")
          facility.code = code_if_present(participant_element)
          facility.locationPeriod = extract_interval(facility_element, './cda:time')
          entry.facilityLocations = [facility]
        end
      end

    end
  end
end
