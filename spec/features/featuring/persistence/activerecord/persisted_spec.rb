# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "checking the persisted value of a feature flags on an activerecord model" do
  include_context :activerecord

  let(:features) {
    Module.new do
      extend Featuring::Declarable
      feature :some_feature
    end
  }

  context "instance has no persisted feature flags" do
    it "returns false" do
      expect(instance.features.persisted?(:some_feature)).to be(false)
    end
  end

  context "feature flag is persisted" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {"some_feature" => true}
    }

    it "returns true" do
      expect(instance.features.persisted?(:some_feature)).to be(true)
    end

    describe "checking the specific persisted value" do
      context "persisted value is true" do
        let(:existing_feature_flag_metadata) {
          {"some_feature" => true}
        }

        it "responds correctly" do
          expect(instance.features.persisted?(:some_feature, true)).to be(true)
          expect(instance.features.persisted?(:some_feature, false)).to be(false)
        end
      end

      context "persisted value is false" do
        let(:existing_feature_flag_metadata) {
          {"some_feature" => false}
        }

        it "responds correctly" do
          expect(instance.features.persisted?(:some_feature, true)).to be(false)
          expect(instance.features.persisted?(:some_feature, false)).to be(true)
        end
      end
    end
  end
end
