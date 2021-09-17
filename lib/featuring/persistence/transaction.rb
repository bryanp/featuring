# frozen_string_literal: true

require "featuring/persistence"

module Featuring
  module Persistence
    # [public] Persist multiple feature flag values for an object at once.
    #
    #   class User < ActiveRecord::Base
    #     extend Featuring::Persistence::ActiveRecord
    #
    #     extend Featuring::Declarable
    #     feature :feature_1
    #     feature :feature_2
    #   end
    #
    #   User.find(1).features.transaction do |features|
    #     features.enable :feature_1
    #     features.disable :feature_2
    #   end
    #
    #   User.find(1).features.feature_1?
    #   => true
    #
    #   User.find(1).features.feature_2?
    #   => false
    #
    class Transaction
      attr_reader :values

      def initialize(features)
        @features = features
        @values = {}
      end

      # [public] Persist the default or computed value for a feature flag within a transaction.
      #
      # See `Featuring::Persistence::Adapter::Methods#persist`.
      #
      def persist(feature, *args)
        @values[feature.to_sym] = @features.fetch_feature_flag_value(feature, *args, raw: true)
      end

      # [public] Set the value for a feature flag within a transaction.
      #
      # See `Featuring::Persistence::Adapter::Methods#set`.
      #
      def set(feature, value)
        @values[feature.to_sym] = !!value
      end

      # [public] Enable a feature flag.
      #
      # See `Featuring::Persistence::Adapter::Methods#enable`.
      #
      def enable(feature)
        @values[feature.to_sym] = true
      end

      # [public] Disable a feature flag.
      #
      # See `Featuring::Persistence::Adapter::Methods#disable`.
      #
      def disable(feature)
        @values[feature.to_sym] = false
      end

      # [public] Reset a feature flag.
      #
      # See `Featuring::Persistence::Adapter::Methods#reset`.
      #
      def reset(feature)
        @values.delete(feature.to_sym)
      end
    end
  end
end
