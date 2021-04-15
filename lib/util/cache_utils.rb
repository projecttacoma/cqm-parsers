module CacheUtils
  class Cache
    @cache = {} # default cache expiry: 5 minutes
    def self.fetch key, expires_in = 300, &block
      if @cache.key?(key) && (@cache[key][:expiration_time] > Time.now.to_i)
        @cache[key][:value]
      else
        if block_given?
          @cache[key] = {value: yield(block), expiration_time: Time.now.to_i + expires_in}
          @cache[key][:value]
        else
          raise Measures::EmptyBlockException.new("No block provided to execute; key: #{key}")
        end
      end
    end

    def self.invalidate
      @cache = {}
    end
  end
end
