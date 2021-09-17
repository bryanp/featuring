# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "overriding the feature flag model on an activerecord model" do
  include_context :activerecord

  let!(:alternate_feature_flag_model) {
    alternate_feature_flag_model = Class.new(feature_flag_model)

    stub_const "AlternateFeatureFlag", alternate_feature_flag_model

    alternate_feature_flag_model
  }

  before do
    model.class_exec(self) do |local|
      define_method :feature_flag_model do
        local.alternate_feature_flag_model
      end
    end

    allow(alternate_feature_flag_model).to receive(:create)
    allow(alternate_feature_flag_model).to receive(:find_by)
  end

  it "uses the specified model" do
    expect(alternate_feature_flag_model).to receive(:create).with(
      flaggable_id: instance_id,
      flaggable_type: model.name,
      metadata: {
        some_feature: true
      }
    )

    instance.features.set :some_feature, true
  end
end
