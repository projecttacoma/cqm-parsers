module Measures
  class ElmParser
    # Fields are combined with the refId to find elm node that corrosponds to the current annotation node.
    @fields = ['expression', 'operand', 'suchThat']
    @html_hash = {"&amp;": '&', "&quot;": '"', "&lt;": '<', "&gt;": '>', "&apos;": "'"}

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
        # Nodes with the 'a' prefix are not leaf nodes
        if child.namespace.respond_to?(:prefix) && child.namespace.prefix == 'a'
          node_type = @localid_to_type_map[child['r']] unless child['r'].nil?
          # Parses the current child recursively. child_define_name will bubble up to indicate which
          # statement is currently being traversed.
          node, child_define_name = parse_node(child)
          node[:node_type] = node_type  unless node_type.nil?
          node[:ref_id] = child['r'] unless child['r'].nil?
          define_name = child_define_name unless child_define_name.nil? 
          ret[:children] << node
        else
          if (/^define/ =~ child.to_html)
            define_name = child.to_html.split("\"")[1]
            # Modify special characters back in the the define_name
            @html_hash.each { |k,v| define_name.gsub!(k.to_s, v) }
          end
          clause_text = child.to_html.gsub(/\t/, "  ")
          # Modify special characters back in the clause text
          @html_hash.each { |k,v| clause_text.gsub!(k.to_s, v) }
          clause = {
            text: clause_text
          }
          clause[:ref_id] = child['r'] unless child['r'].nil?
          ret[:children] << clause
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
