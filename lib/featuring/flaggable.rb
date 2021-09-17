# frozen_string_literal: true

require "forwardable"

require_relative "serializable"

module Featuring
  # Internal concerns related to defining feature flags on a module or class.
  #
  module Flaggable
    def self.extended(object)
      super

      case object
      when Class
        object.include object.internal_feature_checks_module
      when Module
        object.extend object.internal_feature_checks_module
      end
    end

    def self.setup_flaggable_object(object)
      case object
      when Class
        object.extend ClassMethods
        object.prepend InstanceMethods
      when Module
        object.extend Flaggable
        object.extend Delegatable
        object.extend Serializable
      end
    end

    # Contains methods that return the feature's original default value, or block value.
    #
    def internal_feature_module
      @_internal_feature_module ||= Module.new
    end

    # Contains methods that wrap the original values to typecast them into true or false values.
    #
    def internal_feature_checks_module
      @_internal_feature_checks_module ||= Module.new
    end

    def define_feature_flag(name, default, &block)
      # Define a feature check method that returns the default value or the block's return value.
      #
      internal_feature_module.module_eval do
        if method_defined?(name)
          undef_method(name)
        end

        if block
          define_method name, &block
        else
          define_method name do
            default
          end
        end
      end

      # Define a method that typecasts the value returned from the delegator to true/false. This is
      # the method that's called when calling code asks if a feature is enabled. It guarantees that
      # only true or false is returned when checking a feature flag.
      #
      internal_feature_checks_module.module_eval do
        method_name = "#{name}?"

        if method_defined?(method_name)
          undef_method(method_name)
        end

        define_method method_name do |*args|
          fetch_feature_flag_value(name, *args)
        end
      end

      # Keep track of the feature flag we just defined.
      #
      feature_flags << name
    end

    def feature_flags
      @_feature_flags ||= []
    end

    module ClassMethods
      extend Forwardable

      # Delegate flaggable methods to the internal `instance_feature_class`. This lets features be
      # defined through the object, but actually be defined on the internal class.
      #
      def_delegators :instance_feature_class, :internal_feature_module, :internal_feature_checks_module, :define_feature_flag

      # The internal class where feature flags for the object are defined. An instance of this class
      # is returned when calling `object.features`. The object delegates all feature flag definition
      # concerns to this internal class (see the comment above).
      #
      def instance_feature_class
        @_instance_feature_class ||= Class.new do
          extend Flaggable

          # The class is `Flaggable`, but *instances* are `Delegatable`. This lets us delegate
          # dynamically to the parent object (the object `features` is called on).
          #
          include Delegatable

          include Serializable

          def initialize(parent)
            @parent = parent
          end

          # @api private
          def feature_flags
            self.class.feature_flags
          end

          private def internal_feature_delegates_to
            @parent
          end
        end
      end

      def inherited(object)
        # Add the feature check methods to the object's internal feature class.
        #
        object.instance_feature_class.internal_feature_checks_module.include instance_feature_class.internal_feature_checks_module

        # Because we added feature check methods above, include again to make them available.
        #
        object.instance_feature_class.include object.instance_feature_class.internal_feature_checks_module

        # Add the feature methods to the object's internal feature class.
        #
        object.instance_feature_class.internal_feature_module.include instance_feature_class.internal_feature_module
      end
    end

    module InstanceMethods
      # Returns the object's feature context.
      #
      def features
        @_features ||= self.class.instance_feature_class.new(self)
      end
    end
  end
end
