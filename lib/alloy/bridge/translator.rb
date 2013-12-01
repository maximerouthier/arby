require 'alloy/bridge/imports'

module Alloy
  module Bridge
    module Translator
      extend self

      SIG_PREFIX = "this/"

      # Takes an Rjb Proxy object pointing to a list of alloy atoms,
      # and converts them to instances of corresponding aRby sig
      # classes.
      #
      # @param a4atoms [Rjb::Proxy -> SafeList<ExprVar>]
      # @return [Array(Sig)]
      def translate_atoms(a4atoms)
        len = a4atoms.size
        (0...len).map do |idx|
          translate_atom(a4atoms.get(idx))
        end
      end

      # Takes an Rjb Proxy object pointing to an alloy atom, and
      # converts it to an instance of the corresponding aRby sig
      # class.
      #
      # @param a4atom [Rjb::Proxy -> ExprVar]
      # @return [Sig]
      def translate_atom(a4atom)
        sig_name = a4atom.type.toExpr.toString
        sig_name = sig_name[SIG_PREFIX.size..-1] if sig_name.start_with?(SIG_PREFIX)
        sig_cls = Alloy.meta.find_sig(sig_name)
        fail "sig #{sig_name} not found" unless sig_cls
        atom = sig_cls.new()
        atom.label = a4atom.toString
        atom
      end

      # Takes a map of relations to tuples, and a list of aRby atom
      # objects.  Populates the atoms' fields (instance variables) to
      # the values in +map+.  Returns a hash mapping atom labels to
      # atoms.
      #
      # @param atoms [Array(Sig)]
      # @param map [Hash(String, Array(Tuple)] - maps relation names
      #                                          to lists of tuples
      # @return [Hash(String, Sig)]            - maps atom labels to atoms
      def recreate_object_graph(map, atoms)
        label2atom = Hash[atoms.map{|a| [a.label, a]}]
        map.each do |key, value|
          for tuple in value
            lhs   = label2atom[tuple[0].name]
            rhs   = label2atom[tuple[1].name]
            field = lhs.meta.field(key)
            if field.scalar?
              lhs.write_field(field, rhs)
            else
              if !lhs.read_field(field)
                # the field is not a scalar, and this is the first
                # atom we are adding to this field
                lhs.write_field(field, [rhs])
              else
                lhs.write_field(field, lhs.read_field(field).push(rhs))
              end
            end
          end
        end
        label2atom
      end
    end
  end
end
