module Measures
  class ElmDependencyFinder

# DO SOMETHING TO MIMIC THIS:
# BUT WAIT, shouldnt it still be a map??
# cql_definition_dependency_structure[cql_library.library_name].each do |statement_name, dependencies|
#   statement_dependency = CQM::StatementDependency.new(statement_name: statement_name)
#   # TODO: consider removing duplicates
#   statement_dependency.statement_references = dependencies.map do |dependency|
#     CQM::StatementReference.new(library_name: dependency['library_name'], statement_name: dependency['statement_name'])
#   end
#   cql_library.statement_dependencies << statement_dependency
# end


    ##use like         needed_deps_map = ElmDependencyFinder.get_dependencies(elms, main_cql_library)
    attr_reader :needed_deps_map
    private_class_method :new

    def self.get_dependencies(elms, main_cql_library_id)
      instance = new(elms, main_cql_library_id)
      return instance.needed_deps_map
    end

    private
    def initialize(elms, main_cql_library_id)
      @elms = elms
      @all_elms_dep_map = Hash[elms.map { |elm| [elm_id(elm), make_statement_deps_for_elm(elm)] }]
      @needed_deps_map = Hash[elms.map { |elm| [elm_id(elm), {}] }]

      @needed_deps_map[main_cql_library_id] = @all_elms_dep_map[main_cql_library_id]
      @needed_deps_map[main_cql_library_id].each_value do |stmnts|
        stmnts.each { |stmnt| add_external_library_deps(stmnt) }
      end
    end

    private
    def elm_id(elm)
      return elm['library']['identifier']['id']
    end

    private
    def make_library_alias_to_path_hash(elm)
      lib_alias_to_path = { nil => elm_id(elm) } # nil used as default for statements without libraryName reference
      (elm.dig('library','includes','def') || []).each do |library_hash|
        lib_alias_to_path[library_hash['localIdentifier']] = library_hash['path']
      end
      return lib_alias_to_path
    end

    private
    def make_statement_deps_for_elm(elm)
      deps = {}
      lib_alias_to_path = make_library_alias_to_path_hash(elm)
      make_statement_deps_for_elm_helper(elm, nil, deps, lib_alias_to_path)
      deps.each_value {|arr| arr.uniq!}
      return deps
    end

    private
    def make_statement_deps_for_elm_helper(obj, parent_name, deps, lib_alias_to_path)
      if obj.kind_of? Array
        obj.each { |el| make_statement_deps_for_elm_helper(el, parent_name, deps, lib_alias_to_path) }
      elsif obj.kind_of? Hash
        if obj['type'].in?(['ExpressionRef', 'FunctionRef']) && parent_name != 'Patient'
          dep = { :library_name => lib_alias_to_path[obj['libraryName']], :statement_name => obj['name'] }
          deps[parent_name] << dep
        elsif obj.has_key?('name') && obj.has_key?('expression')
          parent_name = obj['name']
          deps[parent_name] = [] unless deps.has_key?('parent_name')
        end
        obj.each_pair do |k,v|
          make_statement_deps_for_elm_helper(v, parent_name, deps, lib_alias_to_path) unless k == 'annotation'
        end
      end
    end

    private
    def add_external_library_deps(statement)
      s_library = statement[:library_name]
      s_name = statement[:statement_name]

      # If key already exists, return
      return if @needed_deps_map.dig(s_library, s_name) != nil

      deps_to_add = @all_elms_dep_map[s_library][s_name]
      @needed_deps_map.deep_merge!( { s_library => { s_name => deps_to_add } } )

      deps_to_add.each { |stmnt| add_external_library_deps(stmnt) }
    end
  end
end
