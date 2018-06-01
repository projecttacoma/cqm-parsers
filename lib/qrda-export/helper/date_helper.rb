module Qrda
  module Export
    module Helper
      module DateHelper

        def value_or_null_flavor(time)
          if time
            return "value='#{DateTime.parse(time).to_formatted_s(:number)}'"
          else
           return "nullFlavor='UNK'"
         end
        end

        def author_time
          "<time #{value_or_null_flavor(self['authorDatetime'])}/>"
        end

        def author_effective_time
          "<effectiveTime #{value_or_null_flavor(self['authorDatetime'])}/>"
        end

        def prevalence_period
          "<effectiveTime>"\
          "<low #{value_or_null_flavor(self['prevalencePeriod']['low'])}/>"\
          "<high #{value_or_null_flavor(self['prevalencePeriod']['high'])}/>"\
          "</effectiveTime>"
        end

        def relevant_period
          "<effectiveTime>"\
          "<low #{value_or_null_flavor(self['relevantPeriod']['low'])}/>"\
          "<high #{value_or_null_flavor(self['relevantPeriod']['high'])}/>"\
          "</effectiveTime>"
        end

        def insurance_provider_period
          start_time = self['start_time'] ? DateTime.strptime(self['start_time'].to_s, '%s').to_s : nil
          end_time = self['end_time'] ? DateTime.strptime(self['end_time'].to_s, '%s').to_s : nil
          "<effectiveTime>"\
          "<low #{value_or_null_flavor(start_time)}/>"\
          "<high #{value_or_null_flavor(self['end_time'])}/>"\
          "</effectiveTime>"
        end

        def medication_duration_effective_time
          "<effectiveTime xsi:type=\"IVL_TS\">"\
          "<low #{value_or_null_flavor(self['relevantPeriod']['low'])}/>"\
          "<high #{value_or_null_flavor(self['relevantPeriod']['high'])}/>"\
          "</effectiveTime>"
        end

        def facility_period
          "<low #{value_or_null_flavor(self['Locationperiod']['low'])}/>"\
          "<high #{value_or_null_flavor(self['Locationperiod']['high'])}/>"
        end

        def incision_datetime
          "<effectiveTime #{value_or_null_flavor(self['incisionDatetime'])}/>"
        end

        def completed_prevalence_period
          self['prevalencePeriod']['high'] ? true : false
        end
      end
    end
  end
end