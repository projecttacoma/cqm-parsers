module Measures
  module Helpers
    def self.elm_id(elm)
      return elm['library']['identifier']['id']
    end

    def self.elm_version(elm)
      return elm['library']['identifier']['version']
    end
  end
end