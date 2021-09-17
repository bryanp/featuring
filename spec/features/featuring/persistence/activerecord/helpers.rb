# frozen_string_literal: true

require "yaml"

require "featuring"
require "featuring/persistence/activerecord"

RSpec.shared_context :activerecord do
  let!(:feature_flag_model) {
    feature_flag_model = Class.new do
      def self.connection(*)
      end

      def self.create(*)
      end

      def self.find_by(*)
      end

      def self.update(*)
      end

      def self.where(*)
      end
    end

    stub_const "FeatureFlag", feature_flag_model

    feature_flag_model
  }

  let(:feature_flag_dataset) {
    double(:feature_flag_dataset)
  }

  let(:features) {
    Module.new do
      extend Featuring::Declarable
      feature :some_feature
    end
  }

  let(:model) {
    model = Class.new do
      attr_reader :id

      def initialize(id:)
        @id = id
      end

      def reload
        :reloaded
      end
    end

    model.class_exec(features) do |features|
      include features

      include Featuring::Persistence::ActiveRecord
    end

    stub_const "ModelWithFeatures", model

    model
  }

  let(:instance) {
    model.new(id: instance_id)
  }

  let(:instance_id) {
    123
  }

  before do
    require "active_record"

    unless ActiveRecord::Base.connected?
      ActiveRecord::Base.establish_connection(
        ENV["DATABASE_URL"] || "postgres://postgres@localhost/"
      )
    end

    allow(feature_flag_model).to receive(:where).with(
      flaggable_type: "ModelWithFeatures",
      flaggable_id: 123
    ).and_return(feature_flag_dataset)

    allow(feature_flag_dataset).to receive(:update_all)
  end
end

RSpec.shared_context :existing_feature_flag do
  let(:existing_feature_flag) {
    double(:existing_feature_flag, metadata: existing_feature_flag_metadata)
  }

  let(:existing_feature_flag_metadata) {
    {}
  }

  let(:feature_flag_model_connection) {
    double(:feature_flag_model_connection)
  }

  before do
    allow(feature_flag_model).to receive(:find_by).with(
      flaggable_id: instance_id,
      flaggable_type: model.name
    ).and_return(existing_feature_flag)

    allow(feature_flag_model).to receive(:connection).and_return(feature_flag_model_connection)
    allow(feature_flag_model_connection).to receive(:execute)
  end
end
