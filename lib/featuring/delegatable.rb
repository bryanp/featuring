# frozen_string_literal: true

require "delegate"

module Featuring
  # Internal concerns related to delegating feature flag checks to parent context, like this:
  #
  #   module Features
  #     extend Featuring::Declarable
  #
  #     feature :some_enabled_feature do |value|
  #       value == internal_value
  #     end
  #
  #     def internal_value
  #       true
  #     end
  #
  #     module_function :internal_value
  #   end
  #
  module Delegatable
    def self.extended(object)
      super

      object.extend ClassMethods
    end

    def self.included(object)
      super

      object.extend ClassMethods
      object.include InstanceMethods
    end

    private def internal_feature_delegates_to
      self
    end

    private def internal_feature_delegator
      @_internal_feature_delegator ||= internal_feature_delegator_class.new(
        internal_feature_delegates_to
      )
    end

    def fetch_feature_flag_value(name, *args)
      !!internal_feature_delegator.public_send(name, *args)
    end

    module ClassMethods
      # Returns the delegator class that responds to all feature check methods and delegates other
      # method calls to its wrapped object.
      #
      def internal_feature_delegator_class
        @_internal_feature_delegator_class ||= Class.new(SimpleDelegator).tap { |klass|
          klass.include internal_feature_module
        }
      end
    end

    module InstanceMethods
      private def internal_feature_delegator_class
        self.class.internal_feature_delegator_class
      end
    end
  end
end
