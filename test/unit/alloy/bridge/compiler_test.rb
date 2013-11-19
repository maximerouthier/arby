require 'my_test_helper'
require 'alloy/bridge/compiler'
require 'alloy/bridge/solution'

module Alloy
  module Bridge

    class CompilerTest < Test::Unit::TestCase
      include SDGUtils::Testing::SmartSetup
      include SDGUtils::Testing::Assertions

      @@model = """
sig A { 
  f: set A,
  g: Int
}

run { 
  #f > 1
} for 4 but exactly 3 A
"""

      def setup_class
        # @@compiler = Compiler.compile(@@model)
        @@a4world = Compiler.parse(@@model)
        @@a4sol = Compiler.execute_command(@@a4world)
      end

      def test_all_atoms
        a4atoms = get_all_atoms
        assert_equal 3, a4atoms.size
        assert_equal "A$0", a4atoms.get(0).toString
        assert_equal "A$1", a4atoms.get(1).toString
        assert_equal "A$2", a4atoms.get(2).toString
      end

      def test_all_fields
        a4fields = get_all_fields
                
        field_names = a4fields.map &:label
        assert_set_equal ["f", "g"], field_names
        
        field_owners = a4fields.map(&:sig).map(&:label)
        assert_seq_equal ["this/A", "this/A"], field_owners
      end

      protected

      def get_all_atoms()  Solution.all_atoms(@@a4sol) end
      def get_all_fields() Compiler.all_fields(@@a4world) end

    end
  end
end
