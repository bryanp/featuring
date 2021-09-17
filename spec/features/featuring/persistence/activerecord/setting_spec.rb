# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "setting a feature flag on an activerecord model" do
  include_context :activerecord

  let(:features) {
    Module.new do
      extend Featuring::Declarable
      feature :some_feature
    end
  }

  def perform
    instance.features.set :some_feature, true
  end

  context "instance has no persisted feature flags" do
    before do
      allow(feature_flag_model).to receive(:create)
      allow(feature_flag_model).to receive(:find_by)

      perform
    end

    it "sets by creating a feature flag record" do
      expect(feature_flag_model).to have_received(:create).with(
        flaggable_id: instance_id,
        flaggable_type: model.name,
        metadata: {
          some_feature: true
        }
      )
    end
  end

  context "feature flag is already set" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {"some_feature" => true}
    }

    before do
      instance.features.set :some_feature, true
    end

    it "sets by updating the existing feature flag record" do
      expect(feature_flag_dataset).to have_received(:update_all).with(
        "metadata = metadata || '{\"some_feature\":true}'"
      )
    end
  end

  context "instance has another persisted feature flag" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {"some_other_feature" => true}
    }

    before do
      instance.features.set :some_feature, true
    end

    it "sets by updating the existing feature flag record" do
      expect(feature_flag_dataset).to have_received(:update_all).with(
        "metadata = metadata || '{\"some_feature\":true}'"
      )
    end
  end
end
