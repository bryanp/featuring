# frozen_string_literal: true

# Attach feature flags to your objects.
#
#   * See `Featuring::Declarable` for how to define and check feature flags.
#   * See `Featuring::Persistence` for how to persist feature flag values.
#
module Featuring
  require_relative "featuring/declarable"
end
