# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "checking persisted feature flags on an activerecord model" do
  include_context :activerecord

  context "feature flag has not been persisted for a record" do
    it "returns the global feature flag value" do
      expect(instance.features.some_feature?).to be(false)
    end
  end

  context "feature flag has been persisted for a record" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {"some_feature" => true}
    }

    it "returns the persisted value" do
      expect(instance.features.some_feature?).to be(true)
    end
  end

  context "multiple feature flags have been persisted for a record" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {"some_feature" => true, :another_feature => true}
    }

    let(:features) {
      super().tap do |features|
        features.module_eval do
          feature :another_feature
        end
      end
    }

    it "returns the persisted value for each feature flag" do
      expect(instance.features.some_feature?).to be(true)
      expect(instance.features.another_feature?).to be(true)
    end
  end

  context "persisted value has changed" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {"some_feature" => true}
    }

    before do
      instance.features.set :some_feature, false
    end

    it "returns the current persisted value" do
      expect(instance.features.some_feature?).to be(false)
    end
  end

  context "feature flag is defined with a block" do
    include_context :existing_feature_flag

    let(:features) {
      Module.new do
        extend Featuring::Declarable
        feature :some_feature do |value|
          value == :foo
        end
      end
    }

    context "persisted value is false" do
      let(:existing_feature_flag_metadata) {
        {"some_feature" => false}
      }

      context "block evaluates to true" do
        it "returns false" do
          expect(instance.features.some_feature?(:foo)).to be(false)
        end
      end

      context "block evaluates to false" do
        it "returns false" do
          expect(instance.features.some_feature?(:bar)).to be(false)
        end
      end
    end

    context "persisted value is true" do
      let(:existing_feature_flag_metadata) {
        {"some_feature" => true}
      }

      context "block evaluates to true" do
        it "returns true" do
          expect(instance.features.some_feature?(:foo)).to be(true)
        end
      end

      context "block evaluates to false" do
        it "returns false" do
          expect(instance.features.some_feature?(:bar)).to be(false)
        end
      end
    end
  end
end
