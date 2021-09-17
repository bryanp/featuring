# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "persisting the default feature flag value on an activerecord model" do
  include_context :activerecord

  let(:features) {
    Module.new do
      extend Featuring::Declarable
      feature :some_feature, true
    end
  }

  def perform
    instance.features.persist :some_feature
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

    let(:features) {
      Module.new do
        extend Featuring::Declarable
        feature :some_feature, false
      end
    }

    let(:existing_feature_flag_metadata) {
      {"some_feature" => true}
    }

    before do
      instance.features.persist :some_feature
    end

    it "sets by updating the existing feature flag record" do
      expect(feature_flag_dataset).to have_received(:update_all).with(
        "metadata = metadata || '{\"some_feature\":false}'"
      )
    end
  end
end
