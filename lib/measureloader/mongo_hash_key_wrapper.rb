module Measures
  # keys can't contain periods https://docs.mongodb.com/manual/reference/limits/#Restrictions-on-Field-Names
  # technically they can't start with dollar sign either, but that's prohibited for CQL naming
  # so:
  #   periods are converted to '^p'
  #   and carets are converted to '^c' therefore we aren't invalidating the use of any characters (e.g. caret)
  class MongoHashKeyWrapper

    def self.wrapKeys(theHash)
      newKeys = Hash.new
      theHash.keys.each do |key|
        if (key.include? '.') || (key.include? '^')
          newKeys[key] = key.gsub(/[\^\.]/, '^' => '^c', '.' => '^p')
        end
      end
      newKeys.each { |old, new| theHash[new] = theHash.delete old}
      # now recurse on any contained hashes
      theHash.each do |key,value|
        if value.respond_to?(:key)
          wrapKeys(value)
        end
      end
    end

    def self.unwrapKeys(theHash)
      newKeys = Hash.new
      theHash.keys.each do |key|
        if (key.include? '^p') || (key.include? '^c')
          newKey = key.gsub(/\^p/, '.')
          newKey.gsub!(/\^c/, '^')
          newKeys[key] = newKey
        end
      end
      newKeys.each { |old, new| theHash[new] = theHash.delete old}
      # now recurse on any contained hashes
      theHash.each do |key,value|
        if value.respond_to?(:key)
          unwrapKeys(value)
        end
      end
    end

  end
end