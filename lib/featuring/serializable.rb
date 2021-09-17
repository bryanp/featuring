# frozen_string_literal: true

module Featuring
  # [public] Concerns related to serializing feature flags and their values.
  #
  module Serializable
    # [public] Returns serialized feature flags (see `Featuring::Serializable::Serializer`).
    #
    #   module Features
    #     extend Featuring::Declarable
    #
    #     feature :some_feature, true
    #   end
    #
    #   Features.serialize
    #   => {
    #     some_feature: true
    #   }
    #
    def serialize
      serializer = Serializer.new(self)
      yield serializer if block_given?
      serializer.to_h
    end

    # [public] Feature flag serialization context (intended to be used through `Featuring::Serializable#serialize`).
    #
    class Serializer
      def initialize(features)
        @features = features
        @included = []
        @excluded = []
        @context = {}
      end

      # Include only specific feature flags in the serialized result.
      #
      #   module Features
      #     extend Featuring::Declarable
      #
      #     feature :feature_1, true
      #     feature :feature_2, true
      #     feature :feature_3, true
      #   end
      #
      #   Features.serialize do |serializer|
      #     serializer.include :feature_1, :feature_3
      #   end
      #   => {
      #     feature_1: true,
      #     feature_2: true
      #   }
      #
      def include(*feature_flags)
        @included.concat(feature_flags)
      end

      # [public] Exclude specific feature flags in the serialized result.
      #
      # @example
      #   module Features
      #     extend Featuring::Declarable
      #
      #     feature :feature_1, true
      #     feature :feature_2, true
      #     feature :feature_3, true
      #   end
      #
      #   Features.serialize do |serializer|
      #     serializer.exclude :feature_1, :feature_3
      #   end
      #   => {
      #     feature_2: true
      #   }
      #
      def exclude(*feature_flags)
        @excluded.concat(feature_flags)
      end

      # [public] Provide context for serializing complex feature flags.
      #
      #   module Features
      #     extend Featuring::Declarable
      #
      #     feature :some_complex_feature do |value|
      #       value == :some_value
      #     end
      #   end
      #
      #   Features.serialize do |serializer|
      #     serializer.context :some_complex_feature, :some_value
      #   end
      #   => {
      #     some_complex_feature: true
      #   }
      #
      def context(feature_flag, *args)
        @context[feature_flag] = args
      end

      # [public] Returns a hash representation of feature flags.
      #
      def to_h
        @features.feature_flags.each_with_object({}) { |feature_flag, serialized|
          if serializable?(feature_flag)
            serialized[feature_flag] = @features.fetch_feature_flag_value(feature_flag, *@context[feature_flag])
          end
        }
      end

      private def serializable?(feature_flag)
        included?(feature_flag) && !excluded?(feature_flag)
      end

      private def included?(feature_flag)
        @included.empty? || @included.include?(feature_flag)
      end

      private def excluded?(feature_flag)
        @excluded.any? && @excluded.include?(feature_flag)
      end
    end
  end
end
