# frozen_string_literal: true

require "featuring"

RSpec.describe "feature flags" do
  let(:features) {
    Module.new do
      extend Featuring::Declarable
    end
  }

  describe "defining a feature flag with a default value" do
    before do
      features.feature :some_enabled_feature, true
    end

    it "returns the default value" do
      expect(features.some_enabled_feature?).to be(true)
    end
  end

  describe "defining a feature flag with a block" do
    before do
      local = self
      features.feature :some_enabled_feature do
        local.calls << Time.now

        true
      end
    end

    let(:calls) {
      []
    }

    it "returns the block's return value" do
      expect(features.some_enabled_feature?).to be(true)
    end

    it "calls the block each time" do
      features.some_enabled_feature?
      features.some_enabled_feature?
      features.some_enabled_feature?

      expect(calls.count).to eq(3)
    end

    context "block accepts an argument" do
      before do
        features.feature :some_conditional_feature do |value|
          !value
        end
      end

      it "passes the argument through" do
        expect(features.some_conditional_feature?(true)).to be(false)
      end
    end

    context "block returns something other than true or false" do
      before do
        features.feature :some_odd_feature do
          "foo"
        end
      end

      it "still returns a boolean value" do
        expect(features.some_odd_feature?).to be(true)
      end
    end
  end

  describe "defining a feature flag with a default value and a block" do
    before do
      features.feature :some_enabled_feature, false do
        true
      end
    end

    it "ignores the default value, giving precedence to the block" do
      expect(features.some_enabled_feature?).to be(true)
    end
  end

  describe "defining a feature flag without a default value or block" do
    before do
      features.feature :some_disabled_feature
    end

    it "returns false" do
      expect(features.some_disabled_feature?).to be(false)
    end
  end

  describe "feature flag call context" do
    before do
      features.module_eval do
        feature :some_enabled_feature do
          value
        end

        def value
          true
        end

        module_function :value
      end
    end

    it "can call methods on the module" do
      expect(features.some_enabled_feature?).to be(true)
    end
  end
end
