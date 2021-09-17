# frozen_string_literal: true

require_relative "delegatable"
require_relative "flaggable"

module Featuring
  # [public] Adds the ability to declare feature flags on a module or class.
  #
  #   module Features
  #     extend Featuring::Declarable
  #
  #     feature :some_feature
  #   end
  #
  #   class User < ActiveRecord::Base
  #     extend Featuring::Declarable
  #
  #     feature :some_feature
  #   end
  #
  # Each feature flag has a corresponding method to check its value:
  #
  #   module Features
  #     extend Featuring::Declarable
  #
  #     feature :some_feature
  #   end
  #
  #   Features.some_feature?
  #   => false
  #
  # When using feature flags on an object, checks are available through the `features` instance method:
  #
  #   class ObjectWithFeatures
  #     extend Featuring::Declarable
  #
  #     feature :some_feature
  #   end
  #
  #   instance = ObjectWithFeatures.new
  #   instance.features.some_feature?
  #   => false
  #
  # When using feature flag blocks, values can be passed through the check method:
  #
  #   module Features
  #     extend Featuring::Declarable
  #
  #     feature :some_feature do |value|
  #       value == :some_value
  #     end
  #   end
  #
  #   Features.some_feature?(:some_value)
  #   => true
  #
  #   Features.some_feature?(:some_other_value)
  #   => false
  #
  # Check methods are guaranteed to only return `true` or `false`:
  #
  #   module Features
  #     extend Featuring::Declarable
  #
  #     feature :some_feature do
  #       :foo
  #     end
  #   end
  #
  #   Features.some_feature?
  #   => true
  #
  # Check methods have access to their context:
  #
  #   class ObjectWithFeatures
  #     extend Featuring::Declarable
  #
  #     feature :some_feature do
  #       enabled?
  #     end
  #
  #     def enabled?
  #       true
  #     end
  #   end
  #
  #   instance = ObjectWithFeatures.new
  #   instance.features.some_feature?
  #   => true
  #
  # Note that this happens through delegators, which means that instance variables are not accessible
  # to the feature flag. For cases like this, define an `attr_accessor`.
  #
  # Feature flags can be defined in various modules and composed together:
  #
  #   module Features
  #     extend Featuring::Declarable
  #     feature :some_feature, true
  #   end
  #
  #   module AllTheFeatures
  #     extend Features
  #
  #     extend Featuring::Declarable
  #     feature :another_feature, true
  #   end
  #
  #   class User < ActiveRecord::Base
  #     include AllTheFeatures
  #   end
  #
  #   instance = ObjectWithFeatures.new
  #
  #   instance.some_feature?
  #   => true
  #
  #   instance.another_feature?
  #   => true
  #
  # Super is fully supported! Here's an example of how it can be useful:
  #
  #   module Features
  #     extend Featuring::Declarable
  #
  #     feature :some_feature do
  #       [true, false].sample
  #     end
  #   end
  #
  #   class User < ActiveRecord::Base
  #     include Features
  #
  #     extend Featuring::Declarable
  #     feature :some_feature do
  #       persisted?(:some_feature) || super()
  #     end
  #   end
  #
  #   User.find(1).features.some_feature?
  #   => true/false at random
  #
  #   User.find(1).features.enable :some_feature
  #
  #   User.find(1).features.some_feature?
  #   => true (always)
  #
  module Declarable
    # [public] Define a named feature with a default value, or a block that returns the default value.
    #
    # By default, a feature flag is disabled. It can be enabled by specifying a value:
    #
    #   module Features
    #     extend Featuring::Declarable
    #
    #     feature :some_feature, true
    #   end
    #
    # Feature flags can also compute a value using a block:
    #
    #   module Features
    #     extend Featuring::Declarable
    #
    #     feature :some_feature do
    #       # perform some complex logic
    #     end
    #   end
    #
    # The truthiness of the block's return value determines if the feature is enabled or disabled.
    #
    def feature(name, default = false, &block)
      define_feature_flag(name, default, &block)
    end

    # Called when an object is extended by `Featuring::Declarable`.
    #
    def self.extended(object)
      super

      Flaggable.setup_flaggable_object(object)
    end

    # Called when an object is extended by a module that is extended by `Featuring::Declarable`.
    #
    def extended(object)
      super

      case object
      when Class
        raise "extending classes with feature flags is not currently supported"
      when Module
        Flaggable.setup_flaggable_object(object)

        # Add the feature check methods to the module that was extended.
        #
        object.internal_feature_checks_module.include internal_feature_checks_module

        # Because we added feature check methods above, extend again to make them available.
        #
        object.extend internal_feature_checks_module

        # Add the feature methods to the module's internal feature module.
        #
        object.internal_feature_module.include internal_feature_module

        # Add our feature flags to the object's feature flags.
        #
        object.feature_flags.concat(feature_flags)
      end
    end

    # Called when a module extended by `Featuring::Declarable` is included into an object.
    #
    def included(object)
      super

      Flaggable.setup_flaggable_object(object)

      # Add the feature check methods to the object's internal feature class.
      #
      object.instance_feature_class.internal_feature_checks_module.include internal_feature_checks_module

      # Because we added feature check methods above, include again to make them available.
      #
      object.instance_feature_class.include object.instance_feature_class.internal_feature_checks_module

      # Add the feature methods to the object's internal feature class.
      #
      object.instance_feature_class.internal_feature_module.include internal_feature_module

      # Add our feature flags to the object's feature flags.
      #
      object.instance_feature_class.feature_flags.concat(feature_flags)
    end
  end
end
