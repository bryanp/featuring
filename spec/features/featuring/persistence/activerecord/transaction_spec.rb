# frozen_string_literal: true

require_relative "./helpers"

RSpec.describe "persisting multiple feature flags on an activerecord model" do
  include_context :activerecord

  let(:features) {
    Module.new do
      extend Featuring::Declarable
      feature :foo
      feature :bar
      feature :baz do |value = nil|
        value == :baz
      end
      feature :qux
      feature :quux
      feature :corge
    end
  }

  def perform
    instance.features.transaction do |features|
      features.set :foo, true
      features.set :bar, false
      features.persist :baz, :baz
      features.disable :qux
      features.enable :quux
      features.set :corge, true
      features.reset :corge
    end
  end

  context "instance has no persisted feature flags" do
    before do
      allow(feature_flag_model).to receive(:create)
      allow(feature_flag_model).to receive(:find_by)

      perform
    end

    it "creates the flags at once" do
      expect(feature_flag_model).to have_received(:create).with(
        flaggable_id: instance_id,
        flaggable_type: model.name,
        metadata: {
          foo: true,
          bar: false,
          baz: true,
          qux: false,
          quux: true
        }
      )
    end
  end

  context "feature flag is already set" do
    include_context :existing_feature_flag

    let(:existing_feature_flag_metadata) {
      {
        foo: false,
        bar: true,
        baz: false,
        qux: true,
        quux: false,
        corge: true
      }
    }

    before do
      perform
    end

    it "updates the flags at once" do
      expect(feature_flag_dataset).to have_received(:update_all).with(
        "metadata = '{\"foo\":true,\"bar\":false,\"baz\":true,\"qux\":false,\"quux\":true}'"
      )
    end

    it "updates the local values" do
      expect(instance.features.foo?).to be(true)
      expect(instance.features.bar?).to be(false)
      expect(instance.features.baz?).to be(true)
      expect(instance.features.qux?).to be(false)
      expect(instance.features.quux?).to be(true)
      expect(instance.features.corge?).to be(false)
    end
  end
end
