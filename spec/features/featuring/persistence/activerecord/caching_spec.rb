# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "caching feature flags on an activerecord model" do
  include_context :activerecord

  include_context :existing_feature_flag

  let(:existing_feature_flag_metadata) {
    {"some_feature" => true}
  }

  let(:updated_feature_flag) {
    double(:updated_feature_flag, metadata: {"some_feature" => false})
  }

  before do
    expect(instance.features.some_feature?).to be(true)

    # Simulate updating the flag in the database.
    #
    allow(feature_flag_model).to receive(:find_by).with(
      flaggable_id: instance_id,
      flaggable_type: model.name
    ).and_return(updated_feature_flag)
  end

  it "caches the value after access" do
    expect(instance.features.some_feature?).to be(true)
  end

  describe "reloading the cached values" do
    before do
      instance.features.reload
    end

    it "reloads" do
      expect(instance.features.some_feature?).to be(false)
    end
  end

  context "model instance is reloaded" do
    before do
      instance.reload
    end

    it "reloads the features" do
      expect(instance.features.some_feature?).to be(false)
    end

    it "returns super's return value" do
      expect(instance.reload).to eq(:reloaded)
    end
  end
end
