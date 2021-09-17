# frozen_string_literal: true

require "featuring"

RSpec.describe "serializing feature flags" do
  shared_examples "serializable" do
    before do
      define_target.feature :some_enabled_feature, true
      define_target.feature :some_disabled_feature, false
      define_target.feature :some_complex_feature do
        true
      end
    end

    let(:serialized) {
      check_target.serialize
    }

    it "serializes all features" do
      expect(serialized).to eq({
        some_enabled_feature: true,
        some_disabled_feature: false,
        some_complex_feature: true
      })
    end

    describe "serializing composed features" do
      let(:features) {
        Module.new.tap do |features|
          features.module_exec(define_target) do |define_target|
            extend Featuring::Declarable
            feature :some_composed_enabled_feature, true
            feature :some_composed_disabled_feature, false
            feature :some_composed_complex_feature do
              true
            end
          end
        end
      }

      before do
        case define_target
        when Class
          define_target.include features
        when Module
          define_target.extend features
        end
      end

      it "serializes all features" do
        expect(serialized).to eq({
          some_enabled_feature: true,
          some_disabled_feature: false,
          some_complex_feature: true,
          some_composed_enabled_feature: true,
          some_composed_disabled_feature: false,
          some_composed_complex_feature: true
        })
      end

      it "does not change how the composed module is serialized" do
        expect(features.serialize).to eq({
          some_composed_enabled_feature: true,
          some_composed_disabled_feature: false,
          some_composed_complex_feature: true
        })
      end
    end

    describe "including specific features in serialization" do
      let(:serialized) {
        check_target.serialize do |serializer|
          serializer.include :some_enabled_feature, :some_complex_feature
        end
      }

      it "serializes the included features" do
        expect(serialized[:some_enabled_feature]).to be(true)
        expect(serialized[:some_complex_feature]).to be(true)
      end

      it "does not serialize features that were not included" do
        expect(serialized[:some_disabled_feature]).to be(nil)
      end
    end

    describe "excluding specific features from serialization" do
      let(:serialized) {
        check_target.serialize do |serializer|
          serializer.exclude :some_enabled_feature, :some_complex_feature
        end
      }

      it "does not serialize features that were excluded" do
        expect(serialized[:some_enabled_feature]).to be(nil)
        expect(serialized[:some_complex_feature]).to be(nil)
      end

      it "serializes features that were not explicitly excluded" do
        expect(serialized[:some_disabled_feature]).to be(false)
      end
    end

    describe "serializing a feature that needs additional context" do
      before do
        define_target.feature :some_contextual_feature do |value|
          value == :foo
        end
      end

      it "errors" do
        expect {
          serialized
        }.to raise_error(ArgumentError)
      end

      context "context is provided" do
        let(:serialized) {
          check_target.serialize do |serializer|
            serializer.include :some_contextual_feature
            serializer.context :some_contextual_feature, :foo
          end
        }

        it "serializes" do
          expect(serialized).to eq({
            some_contextual_feature: true
          })
        end
      end
    end
  end

  context "feature flag module" do
    it_behaves_like "serializable" do
      let(:check_target) {
        define_target
      }

      let(:define_target) {
        Module.new do
          extend Featuring::Declarable
        end
      }
    end
  end

  context "feature flag object" do
    it_behaves_like "serializable" do
      let(:check_target) {
        define_target.new.features
      }

      let(:define_target) {
        Class.new.class_eval do
          extend Featuring::Declarable
        end
      }
    end
  end
end
