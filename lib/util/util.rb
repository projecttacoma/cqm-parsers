module Utilities
  
  # Traverse each key, value of the hash and any nested hashes (including those in arrays)
  # E.G. to deep transfrom do:
  #   deep_traverse_hash(obj) { |hash, k, v| hash[k] = v.upcase if v.is_a?(String) }
  def self.deep_traverse_hash(obj, &block)
    if obj.is_a? Array
      obj.each { |val| deep_traverse_hash(val, &block) }
    elsif obj.is_a?(Hash)
      obj.each_pair do |k,v|
        deep_traverse_hash(v, &block)
        block.call(obj, k, v)
      end
    end
  end
end