module Measures
  class ElmParser
    # Fields are combined with the refId to find elm node that corrosponds to the current annotation node.
    @fields = ['expression', 'operand', 'suchThat']

    def self.parse(doc)
      @doc = doc
      @localid_to_type_map = generate_localid_to_type_map
      ret = {
        statements: [],
        identifier: {}
      }
      # extract library identifier data
      ret[:identifier][:id] = @doc.css("identifier").attr("id").value
      ret[:identifier][:version] = @doc.css("identifier").attr("version").value

      # extracts the fields of type "annotation" and their children.
      annotations = @doc.css("annotation")
      annotations.each do |node|
        node, define_name = parse_node(node)
        unless define_name.nil?
          node[:define_name] = define_name
          ret[:statements] << node
        end
      end
      ret
    end

    # Recursive function that traverses the annotation tree and constructs a representation
    # that will be compatible with the front end.
    def self.parse_node(node)
      ret = {
        children: []
      }
      define_name = nil
      node.children.each do |child|
        if child.is_a?(Nokogiri::XML::Text) # leaf node
          clause_text = child.content.gsub(/\t/, "  ")
          clause = {
            text: clause_text
          }
          clause[:ref_id] = child['r'] unless child['r'].nil?
          ret[:children] << clause
          define_name = clause_text.split("\"")[1] if clause_text.strip.starts_with?("define")
        else
          node_type = @localid_to_type_map[child['r']] unless child['r'].nil?
          # Parses the current child recursively. child_define_name will bubble up to indicate which
          # statement is currently being traversed.
          node, child_define_name = parse_node(child)
          node[:node_type] = node_type  unless node_type.nil?
          node[:ref_id] = child['r'] unless child['r'].nil?
          ret[:children] << node
          define_name = child_define_name unless child_define_name.nil?
        end
      end
      return ret, define_name
    end

    def self.generate_localid_to_type_map
      localid_to_type_map = {}
      @fields.each do |field|
        nodes = @doc.css(field + '[localId][xsi|type]')
        nodes.each {|node| localid_to_type_map[node['localId']] = node['xsi:type']}
      end
      return localid_to_type_map
    end
  end
end
