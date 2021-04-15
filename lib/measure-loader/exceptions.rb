module Measures
  class ValueSetException < StandardError
  end
  class HQMFException < StandardError
  end
  class MeasureLoadingInvalidPackageException < StandardError
  end
  class MeasureLoadingException < StandardError
  end

  class RestException < StandardError
    def initialize(message)
      super(message)
    end
  end

  class EmptyBlockException < StandardError
    def initialize(message)
      super(message)
    end
  end
end
