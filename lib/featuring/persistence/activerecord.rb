# frozen_string_literal: true

require_relative "../persistence"
require_relative "adapter"

module Featuring
  module Persistence
    # [public] Persists feature flag values using an ActiveRecord model. Postgres is currently the only
    # supported database (see `Featuring::Persistence` for details on how to use persistence).
    #
    #   class User < ActiveRecord::Base
    #     extend Featuring::Persistence::ActiveRecord
    #
    #     extend Featuring::Declarable
    #     feature :some_feature
    #   end
    #
    #   User.find(1).features.enable :some_feature
    #   User.find(1).features.some_feature?
    #   => true
    #
    module ActiveRecord
      extend Adapter

      # [public] Methods to be added to the flaggable object.
      #
      module Flaggable
        def reload
          features.reload

          super
        end
      end

      # [public] Returns the ActiveRecord model used to persist feature flag values.
      #
      def feature_flag_model
        ::FeatureFlag
      end

      class << self
        def fetch(target)
          target.feature_flag_model.find_by(flaggable_id: target.id, flaggable_type: target.class.name)&.metadata
        end

        def create(target, **features)
          target.feature_flag_model.create(
            flaggable_id: target.id,
            flaggable_type: target.class.name,
            metadata: features
          )
        end

        def update(target, **features)
          scoped_dataset(target).update_all("metadata = metadata || '#{features.to_json}'")
        end

        def replace(target, **features)
          scoped_dataset(target).update_all("metadata = '#{features.to_json}'")
        end

        private def scoped_dataset(target)
          target.feature_flag_model.where(
            flaggable_type: target.class.name,
            flaggable_id: target.id
          )
        end
      end
    end
  end
end
