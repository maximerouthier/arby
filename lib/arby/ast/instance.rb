require 'arby/ast/bounds'
require 'arby/ast/tuple_set'

module Arby
  module Ast

    # @typeparam Atom     - anything that responds to :label
    # @typeparam TupleSet - any array-like class
    #
    # @attr label2atom [Hash(String, Atom)]        - atom labels to atoms
    # @attr fld2tuples [Hash(String, TupleSet)]    - field names to tuples
    # @attr skolem2tuples [Hash(String, TupleSet)] - skolem names to tuples
    class Instance

      # @param atoms [Array(Atom)]
      # @param fld_map [Hash(String, TupleSet]    - field names to list of tuples
      # @param skolem_map [Hash(String, TupleSet] - skolem names to list of tuples
      def initialize(atoms=[], fld_map={}, skolem_map={}, dup=true, model=nil)
        @model         = model
        @label2atom    = Hash[atoms.map{|a| [a.label, a]}]
        @fld2tuples    = dup ? fld_map.dup : fld_map
        @skolem2tuples = dup ? skolem_map.dup : skolem_map

        ([@label2atom, @fld2tuples, @skolem2, self] +
          @fld2tuples.values + @skolem2tuples.values).each(&:freeze)
      end

      def model()      @model end
      def atoms()      @label2atom.values end
      def fields()     @fld2tuples.keys end
      def skolems()    @skolem2tuples.keys end

      def atom(label)
        case label
        when Integer then label
        when String, Symbol
          label = label.to_s
          @label2atom[label] || (Integer(label) rescue nil)
        else
          fail "label must be either Integer, String or Symbol but is #{label.class}"
        end
      end
      def field(fld)   @fld2tuples[fld] end
      def skolem(name) @skolem2tuples[name] end

      def atom!(label)  atom(label)  or fail("atom `#{label}' not found") end
      def field!(fld)   field(fld)   or fail("field `#{fld}' not found") end
      def skolem!(name) skolem(name) or fail("skolem `#{name}' not found") end

      def [](name) atom(name) || skolem(name) || field(name) end

      def to_bounds
        bounds = Bounds.new
        atoms.group_by(&:class).each do |cls, atoms|
          bounds.bound_exactly(cls, atoms) if cls < Arby::Ast::ASig
        end
        @fld2tuples.each{|fld, ts| bounds.bound_exactly(fld, ts)}
        bounds
      end

      def to_s
        atoms_str = atoms.map(&:label).join(', ')
        "atoms:\n  #{atoms_str}\n" +
          "fields:\n  #{@fld2tuples}\n" +
          "skolems:\n  #{@skolem2tuples}"
      end
    end

  end
end

