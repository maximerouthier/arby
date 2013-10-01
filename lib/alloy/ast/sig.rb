require 'alloy/alloy_event_constants.rb'
require 'alloy/ast/arg'
require 'alloy/ast/expr'
require 'alloy/ast/field'
require 'alloy/ast/fun'
require 'alloy/ast/sig_meta'
require 'alloy/relations/relation'
require 'alloy/utils/codegen_repo'
require 'sdg_utils/meta_utils'
require 'sdg_utils/random'

require 'alloy/dsl/helpers'
require 'alloy/dsl/sig_api'

module Alloy
  module Ast

    #=========================================================================
    # == Module ASig::Static
    #=========================================================================
    module ASig

      module Static
        def inherited(subclass)
          super
          fail "The +meta+ method hasn't been defined for class #{self}" unless meta
          meta.add_subsig(subclass)
        end

        def new(*a, &b)
          sig_inst = super
          if Alloy.symbolic_mode?
            sig_inst.make_me_sym_expr
          end
          sig_inst
        end

        def to_alloy_expr() Expr::SigExpr.new(self) end

        def add_method_for_field(fld)
          unless respond_to?(fld.name.to_sym)
            define_singleton_method fld.name do
              get_cls_field(fld)
            end
            # class_eval <<-RUBY, __FILE__, __LINE__+1
            #   def self.#{fld.name}() get_cls_field(#{fld.name.to_s.inspect}) end
            # RUBY
          end
          if oldest_ancestor
            superclass.add_method_for_field(fld)
          end
        end

        def get_cls_field(fld)
          if Alloy.symbolic_mode?
            to_alloy_expr.send fld.name.to_sym
          else
            fld
          end
        end

        def method_missing(sym, *args, &block)
          to_alloy_expr().send sym, *args, &block
          # # TODO: remove these functinos as well, and instead generate
          # #       methods for alloy funs
          # if block.nil? && fun=meta.any_fun(sym)
          #   # use the instance method bound to self.to_alloy_expr
          #   to_alloy_expr().apply_call(fun, *args)
          # else
          #   return super
          # end
        end

        # @see +SigMeta#abstract?+
        # @return [TrueClass, FalseClass]
        def abstract?() meta.abstract? end

        # @see +SigMeta#set_abstract+
        def set_abstract() meta.set_abstract end
        # @see +SigMeta#set_one+
        def set_one() meta.set_one end
        # @see +SigMeta#set_lone+
        def set_lone() meta.set_lone end

        # @see +SigMeta#placeholder?+
        # @return [TrueClass, FalseClass]
        def placeholder?() meta.placeholder? end

        # @see +SigMeta#ignore_abstract+
        # @return [Class, NilClass]
        def oldest_ancestor(ignore_abstract=false)
          meta.oldest_ancestor(ignore_abstract)
        end

        # Returns highest non-placeholder ancestor of +self+ in the
        # inheritance hierarchy or self.
        def alloy_root
          meta.oldest_ancestor(false) || self
        end

        def all_supersigs()  meta.all_supersigs end
        def all_subsigs()  meta.all_subsigs end

        #------------------------------------------------------------------------
        # Returns a string representation of this +Sig+ conforming to
        # the Alloy syntax
        #------------------------------------------------------------------------
        def to_alloy
          Alloy::Utils::AlloyPrinter.export_to_als(self)
#           psig = superclass
#           psig_str = (psig != Sig.class) ? "extends #{psig.relative_name} " : ""
#           <<-EOS
# sig #{relative_name} #{psig_str} {
# #{meta.fields_to_alloy}

# // inv fields (synthesized)
# /*
# #{meta.inv_fields_to_alloy}
# */
# }
# EOS
        end

        #------------------------------------------------------------------------
        # Defines the +meta+ method which returns some meta info
        # about this sig's fields
        #------------------------------------------------------------------------
        def _define_meta()
          meta = Alloy::Ast::SigMeta.new(self)
          define_singleton_method(:meta, lambda {meta})
          meta
        end

        #------------------------------------------------------------------------
        # Checks whether the specified hash contains exactly one
        # entry, whose key is a valid identifier, and whose value is a
        # subtype of the specified type (`expected_type')
        # ------------------------------------------------------------------------
        def _check_single_fld_hash(hash, expected_type=Object)
          msg1 = "Hash expected, got #{hash.class} instead"
          msg2 = "Expected exactly one entry, got #{hash.length}"
          raise ArgumentError, msg1 unless hash.kind_of? Hash
          raise ArgumentError, msg2 unless hash.length == 1

          varname, type = hash.first
          msg = "`#{varname}' is not a proper identifier"
          raise ArgumentError, msg unless SDGUtils::MetaUtils.check_identifier(varname)
          Alloy::Ast::TypeChecker.check_type(expected_type, type)
        end

        def __parent() nil end
      end
    end

    #------------------------------------------
    # == Module ASig
    #------------------------------------------
    module ASig
      include SDGUtils::ShadowMethods

      def self.included(base)
        base.extend(Alloy::Dsl::StaticHelpers)
        base.extend(Static)
        base.extend Alloy::Dsl::SigDslApi
        base.send :include, Alloy::Dsl::InstanceHelpers
        base.send :__created
      end

      def meta() self.class.meta end

      def initialize(*args)
        super
        init_default_transient_values
      end

      def read_field(fld)       send Alloy::Ast::Field.getter_sym(fld) end
      def write_field(fld, val) send Alloy::Ast::Field.setter_sym(fld), val end

      def make_me_sym_expr(name="self")
        p = __parent()
        if ASig === p
          p.make_me_sym_expr("#{name}_parent")
        end
        Alloy::Ast::Expr.as_atom(self, name)
        self
      end

      def __parent() nil end

      protected

      include Alloy::EventConstants

      def intercept_read(fld)
        _fld_pre_read(fld)
        value = yield
        _fld_post_read(fld, value)
        value
      end

      def intercept_write(fld, value)
        _fld_pre_write(fld, value)
        yield
        _fld_post_write(fld, value)
      end

      def _fld_pre_read(fld)
        Alloy.boss.fire E_FIELD_TRY_READ, :object => self, :field => fld
        _check_fld_read_access(fld)
      end

      def _fld_pre_write(fld, val)
        Alloy.boss.fire E_FIELD_TRY_WRITE, :object => self, :field => fld, :value => val
        _check_fld_write_access(fld, val)
      end

      def _fld_post_read(fld, val)
        Alloy.boss.fire E_FIELD_READ, :object => self, :field => fld, :return => val
      end

      def _fld_post_write(fld, val)
        Alloy.boss.fire E_FIELD_WRITTEN, :object => self, :field => fld, :value => val
      end

      def init_default_transient_values
        meta.tfields.each do |tf|
          if tf.type.unary? && tf.type.range.cls.primitive?
            val = tf.type.range.cls.default_value
            self.write_field(tf, val)
          end
        end
      end

      # checks field read access and raises an error if a violation is detected
      def _check_fld_read_access(fld)
        #TODO
        true
      end

      # checks field write access and raises an error if a violation is detected
      def _check_fld_write_access(fld, value)
        #TODO
        true
      end

    end

    #================================================================
    # == Class Sig
    #================================================================
    class Sig
      include ASig
      meta.set_placeholder
    end

    def self.create_sig(name, super_cls=Alloy::Ast::Sig)
      sb = Alloy::Dsl::SigBuilder.new({
             :superclass => super_cls,
             :return     => :as_is
      }).sig(name)
    end

  end
end
