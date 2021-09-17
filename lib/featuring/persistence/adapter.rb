# frozen_string_literal: true

require "featuring/persistence"
require "featuring/persistence/transaction"

module Featuring
  module Persistence
    # [public] Defines the behavior for feature flag adapters.
    #
    # Adapters are modules that are extended by {Adapter}. They must define three methods:
    #
    #   1. `fetch`: Returns persisted feature flag values for a given object.
    #
    #   2. `create`: Creates feature flags for a given object.
    #
    #   3. `update`: Updates feature flags for a given object.
    #
    #   4. `replace`: Replaces feature flags for a given object.
    #
    # See `Featuring::Persistence::ActiveRecord` for a complete example.
    #
    module Adapter
      def included(object)
        object.instance_feature_class.prepend Methods

        object.instance_feature_class.module_exec(self) do |adapter|
          define_method :feature_flag_adapter do
            adapter
          end
        end

        # Give adapters the ability to extend the object with persistent flags.
        #
        if const_defined?("Flaggable", false)
          object.prepend(const_get("Flaggable"))
        end
      end

      module Methods
        # [public] Persist the default or computed value for a feature flag.
        #
        #   class User < ActiveRecord::Base
        #     extend Featuring::Persistence::ActiveRecord
        #
        #     extend Featuring::Declarable
        #     feature :feature_1, true
        #   end
        #
        #   User.find(1).features.persist :feature_1
        #   User.find(1).features.feature_1?
        #   => true
        #
        # Passing arguments to a feature flag block:
        #
        #   class User < ActiveRecord::Base
        #     extend Featuring::Persistence::ActiveRecord
        #
        #     extend Featuring::Declarable
        #     feature :feature_1 do |value|
        #       value == :foo
        #     end
        #   end
        #
        #   User.find(1).features.persist :feature_1, :bar
        #   User.find(1).features.feature_1?
        #   => false
        #
        def persist(feature, *args)
          create_or_update_feature_flags(feature => fetch_feature_flag_value(feature, *args, raw: true))
        end

        # [public] Ensure that a feature flag is *not* persisted, falling back to its default value.
        #
        #   class User < ActiveRecord::Base
        #     extend Featuring::Persistence::ActiveRecord
        #
        #     extend Featuring::Declarable
        #     feature :feature_1, true
        #   end
        #
        #   User.find(1).features.disable :feature_1
        #   User.find(1).features.feature_1?
        #   => false
        #
        #   User.find(1).features.reset :feature_1
        #   User.find(1).features.feature_1?
        #   => true
        #
        def reset(feature)
          if persisted?(feature)
            features = persisted_flags
            features.delete(feature)
            feature_flag_adapter.replace(@parent, **features.symbolize_keys)
          end
        end

        # [public] Set the value for a feature flag.
        #
        #   class User < ActiveRecord::Base
        #     extend Featuring::Persistence::ActiveRecord
        #
        #     extend Featuring::Declarable
        #     feature :feature_1
        #   end
        #
        #   User.find(1).features.set :feature_1, true
        #   User.find(1).features.feature_1?
        #   => true
        #
        def set(feature, value)
          create_or_update_feature_flags(feature.to_sym => !!value)
        end

        # [public] Enable a feature flag.
        #
        #   class User < ActiveRecord::Base
        #     extend Featuring::Persistence::ActiveRecord
        #
        #     extend Featuring::Declarable
        #     feature :feature_1
        #   end
        #
        #   User.find(1).features.enable :feature_1
        #   User.find(1).features.feature_1?
        #   => true
        #
        def enable(feature)
          create_or_update_feature_flags(feature.to_sym => true)
        end

        # [public] Disable a feature flag.
        #
        #   class User < ActiveRecord::Base
        #     extend Featuring::Persistence::ActiveRecord
        #
        #     extend Featuring::Declarable
        #     feature :feature_1
        #   end
        #
        #   User.find(1).features.disable :feature_1
        #   User.find(1).features.feature_1?
        #   => false
        #
        def disable(feature)
          create_or_update_feature_flags(feature.to_sym => false)
        end

        # [public] Reload feature flag values for the object.
        #
        def reload
          @_persisted_flags = nil
        end

        # [public] Start a transaction in which multiple feature flags values can be persisted at once.
        #
        # See `Featuring::Persistence::Transaction`.
        #
        def transaction
          transaction = Transaction.new(self)
          yield transaction
          create_or_update_feature_flags(__perform: :replace, **transaction.values)
        end

        # [public] Returns `true` if the feature flag is persisted, optionally with the specified value.
        #
        #   class User < ActiveRecord::Base
        #     extend Featuring::Persistence::ActiveRecord
        #
        #     extend Featuring::Declarable
        #     feature :feature_1
        #   end
        #
        #   User.find(1).features.persisted?(:feature_1)
        #   => false
        #
        #   User.find(1).features.enable :feature_1
        #
        #   User.find(1).features.persisted?(:feature_1)
        #   => true
        #   User.find(1).features.persisted?(:feature_1, true)
        #   => true
        #   User.find(1).features.persisted?(:feature_1, false)
        #   => false
        #
        def persisted?(name = nil, value = value_omitted = true)
          if name && persisted_flags
            persisted_flags.key?(name.to_sym) && (value_omitted || persisted(name) == value)
          else
            !persisted_flags.nil?
          end
        end

        private def persisted(name)
          persisted_flags[name.to_sym]
        end

        private def persisted_flags
          @_persisted_flags ||= fetch_flags
        end

        private def fetch_flags
          if (flags = feature_flag_adapter.fetch(@parent))
            ActiveSupport::HashWithIndifferentAccess.new(flags)
          end
        end

        private def create_or_update_feature_flags(__perform: :update, **features)
          if persisted?
            feature_flag_adapter.public_send(__perform, @parent, **features)

            # Update the local persisted values to match.
            #
            features.each do |feature, value|
              persisted_flags[feature] = value
            end

            # Remove local feature flags if no longer present.
            #
            persisted_flags.each_key do |feature|
              unless features.include?(feature.to_sym)
                persisted_flags.delete(feature)
              end
            end
          else
            feature_flag_adapter.create(@parent, **features)
          end
        end

        def fetch_feature_flag_value(name, *args, raw: false)
          if !raw && persisted?(name)
            if feature_flag_has_block?(name)
              persisted(name) && super(name, *args)
            else
              persisted(name)
            end
          else
            super(name, *args)
          end
        end

        private def feature_flag_has_block?(name)
          internal_feature_delegator.method(name).arity > 0
        end
      end
    end
  end
end
