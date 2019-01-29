module Measures
  module ElmDependencyFinder
    class << self

      def find_dependencies(cql_library_files, main_cql_library_id)
        elms = cql_library_files.map(&:elm)
        all_elms_dep_map = Hash[elms.map { |elm| [Helpers.elm_id(elm), make_statement_deps_for_elm(elm)] }]
        needed_deps_map = Hash[elms.map { |elm| [Helpers.elm_id(elm), {}] }]

        needed_deps_map[main_cql_library_id] = all_elms_dep_map[main_cql_library_id]
        needed_deps_map[main_cql_library_id].each_value do |stmnts|
          stmnts.each { |stmnt| deep_add_external_library_deps(stmnt, needed_deps_map, all_elms_dep_map) }
        end
        return needed_deps_map
      end

      private

      def make_library_alias_to_path_hash(elm)
        lib_alias_to_path = { nil => Helpers.elm_id(elm) } # nil value used for statements without libraryName
        (elm.dig('library','includes','def') || []).each do |library_hash|
          lib_alias_to_path[library_hash['localIdentifier']] = library_hash['path']
        end
        return lib_alias_to_path
      end

      def make_statement_deps_for_elm(elm)
        deps = {}
        lib_alias_to_path = make_library_alias_to_path_hash(elm)
        make_statement_deps_for_elm_helper(elm, nil, deps, lib_alias_to_path)
        deps.each_value(&:uniq!)
        return deps
      end

      def make_statement_deps_for_elm_helper(obj, parent_name, deps, lib_alias_to_path)
        if obj.is_a? Array
          obj.each { |el| make_statement_deps_for_elm_helper(el, parent_name, deps, lib_alias_to_path) }
        elsif obj.is_a? Hash
          if obj['type'].in?(['ExpressionRef', 'FunctionRef']) && parent_name != 'Patient'
            dep = { library_name: lib_alias_to_path[obj['libraryName']], statement_name: obj['name'] }
            deps[parent_name] << dep
          elsif obj.key?('name') && obj.key?('expression')
            parent_name = obj['name']
            deps[parent_name] = [] unless deps.key?('parent_name')
          end
          obj.each_pair do |k,v|
            make_statement_deps_for_elm_helper(v, parent_name, deps, lib_alias_to_path) unless k == 'annotation'
          end
        end
      end
      
      def deep_add_external_library_deps(statement, needed_deps_map, all_elms_dep_map)
        statement_library = statement[:library_name]
        statement_name = statement[:statement_name]

        return unless needed_deps_map.dig(statement_library, statement_name).nil? # return if key already exists

        if all_elms_dep_map[statement_library].nil?
          raise MeasureLoadingInvalidPackageException.new("Elm library #{statement_library} referenced but not found.")
        end
        if all_elms_dep_map[statement_library][statement_name].nil?
          raise MeasureLoadingInvalidPackageException.new("Elm statement #{statement_library.statement_name} referenced but not found.")
        end
        deps_to_add = all_elms_dep_map[statement_library][statement_name]
        needed_deps_map.deep_merge!(statement_library => { statement_name => deps_to_add })

        deps_to_add.each { |stmnt| deep_add_external_library_deps(stmnt, needed_deps_map, all_elms_dep_map) }
      end
      
    end
  end
end
