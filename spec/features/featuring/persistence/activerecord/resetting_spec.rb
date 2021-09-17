# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "resetting the value for a feature flag on an activerecord model" do
  include_context :activerecord

  let(:features) {
    Module.new do
      extend Featuring::Declarable
      feature :some_feature, true
    end
  }

  context "instance has no persisted feature flags" do
    before do
      allow(feature_flag_model).to receive(:create)
      allow(feature_flag_model).to receive(:update)
      allow(feature_flag_model).to receive(:find_by)

      instance.features.reset :some_feature
    end

    it "does not create or update" do
      expect(feature_flag_model).not_to have_received(:create)
      expect(feature_flag_model).not_to have_received(:update)
    end
  end

  context "feature flag is set" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {some_feature: true, another_feature: false}
    }

    let(:features) {
      Module.new do
        extend Featuring::Declarable
        feature :some_feature, false
      end
    }

    before do
      instance.features.reset :some_feature
    end

    it "removes the persisted value with an update" do
      expect(feature_flag_dataset).to have_received(:update_all).with(
        "metadata = '{\"another_feature\":false}'"
      )
    end

    it "updates the local values" do
      expect(instance.features.some_feature?).to be(false)
    end
  end
end
