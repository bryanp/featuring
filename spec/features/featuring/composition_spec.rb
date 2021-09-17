# frozen_string_literal: true

require "featuring"

RSpec.describe "composing feature flags" do
  let(:shared_feature_flags) {
    Module.new do
      extend Featuring::Declarable

      feature :some_enabled_feature, true
    end
  }

  describe "extending a feature flag module with shared feature flags" do
    let(:features) {
      Module.new.tap do |features|
        features.module_exec(self) do |local|
          extend Featuring::Declarable
          extend local.shared_feature_flags

          feature :another_enabled_feature, true
        end
      end
    }

    it "extends the module with the shared flags" do
      expect(features.some_enabled_feature?).to be(true)
    end

    it "defines the new flag" do
      expect(features.another_enabled_feature?).to be(true)
    end

    it "does not define the new flag globally" do
      expect {
        shared_feature_flags.another_enabled_feature?
      }.to raise_error(NoMethodError)
    end

    context "module overrides a shared feature flag" do
      let(:features) {
        Module.new.tap do |features|
          features.module_exec(self) do |local|
            extend Featuring::Declarable
            extend local.shared_feature_flags

            feature :some_enabled_feature, false
          end
        end
      }

      it "calls the new feature flag" do
        expect(features.some_enabled_feature?).to be(false)
      end

      describe "calling super from the new feature flag" do
        let(:features) {
          Module.new.tap do |features|
            features.module_exec(self) do |local|
              extend Featuring::Declarable
              extend local.shared_feature_flags

              feature :some_enabled_feature do
                super()
              end
            end
          end
        }

        it "calls super" do
          expect(features.some_enabled_feature?).to be(true)
        end
      end
    end
  end

  describe "including a feature flag module into an object" do
    let(:object) {
      Class.new.tap do |object|
        object.class_exec(self) do |local|
          include local.shared_feature_flags
        end
      end
    }

    it "it makes the feature flag check available on instances through the features context" do
      expect(object.new.features.some_enabled_feature?).to be(true)
    end

    it "does not make the feature flag check available directly on instances" do
      expect {
        object.new.some_enabled_feature?
      }.to raise_error(NoMethodError)
    end

    it "does not make the feature flag check available on classes" do
      expect {
        object.some_enabled_feature?
      }.to raise_error(NoMethodError)
    end

    context "object overrides a shared feature flag" do
      let(:object) {
        super().tap do |object|
          object.extend Featuring::Declarable
          object.feature :some_enabled_feature, false
        end
      }

      it "calls the new feature flag" do
        expect(object.new.features.some_enabled_feature?).to be(false)
      end

      describe "calling super from the new feature flag" do
        let(:object) {
          super().tap do |object|
            object.extend Featuring::Declarable
            object.feature :some_enabled_feature do
              super()
            end
          end
        }

        it "calls super" do
          expect(object.new.features.some_enabled_feature?).to be(true)
        end
      end
    end

    context "block returns something other than true or false" do
      let(:object) {
        super().tap do |object|
          object.extend Featuring::Declarable
          object.feature :some_odd_feature do
            "foo"
          end
        end
      }

      it "still returns a boolean value" do
        expect(object.new.features.some_odd_feature?).to be(true)
      end
    end

    describe "feature flag call context" do
      let(:shared_feature_flags) {
        Module.new do
          extend Featuring::Declarable

          feature :some_enabled_feature do |value|
            name == value
          end
        end
      }

      let(:object) {
        super().tap do |object|
          object.class_eval do
            attr_reader :name

            def initialize(name = :default)
              @name = name
            end
          end
        end
      }

      it "can call methods on the instance" do
        expect(object.new(:foo).features.some_enabled_feature?(:foo)).to be(true)
        expect(object.new(:foo).features.some_enabled_feature?(:bar)).to be(false)
      end
    end

    describe "subclassing the object" do
      let(:object) {
        super().tap do |object|
          object.extend Featuring::Declarable
          object.feature :another_enabled_feature, true
        end
      }

      let(:subclass) {
        Class.new(object) do
          feature :yet_another_enabled_feature, true
        end
      }

      it "inherits global feature flags" do
        expect(subclass.new.features.some_enabled_feature?).to be(true)
      end

      it "inherits feature flags from the parent class" do
        expect(subclass.new.features.another_enabled_feature?).to be(true)
      end

      it "respects feature flags defined on the subclass" do
        expect(subclass.new.features.yet_another_enabled_feature?).to be(true)
      end

      it "does not make subclass feature flags available to the parent" do
        expect {
          object.new.features.yet_another_enabled_feature?
        }.to raise_error(NoMethodError)
      end

      describe "feature flag call context" do
        let(:object) {
          super().tap do |object|
            object.extend Featuring::Declarable
            object.feature :another_enabled_feature do |value|
              name == value
            end
          end
        }

        let(:subclass) {
          Class.new(object) do
            attr_reader :name

            def initialize(name = :default)
              @name = name
            end
          end
        }

        it "calls inherited flags in context of the subclass" do
          expect(subclass.new(:foo).features.another_enabled_feature?(:foo)).to be(true)
          expect(subclass.new(:foo).features.another_enabled_feature?(:bar)).to be(false)
        end
      end

      context "subclass overrides a feature flag" do
        let(:subclass) {
          Class.new(object) do
            feature :another_enabled_feature, false
          end
        }

        it "calls the new feature flag" do
          expect(subclass.new.features.another_enabled_feature?).to be(false)
        end

        describe "calling super from the new feature flag" do
          let(:subclass) {
            Class.new(object) do
              feature :another_enabled_feature do
                super()
              end
            end
          }

          it "calls super" do
            expect(subclass.new.features.another_enabled_feature?).to be(true)
          end
        end
      end
    end
  end

  describe "including a composed feature flag module into an object" do
    let(:feature_flags) {
      Module.new.tap do |feature_flags|
        feature_flags.module_exec(self) do |local|
          extend local.shared_feature_flags

          extend Featuring::Declarable
          feature :another_enabled_feature, true
        end
      end
    }

    let(:object) {
      Class.new.tap do |object|
        object.class_exec(self) do |local|
          include local.feature_flags
        end
      end
    }

    it "makes all composed feature flag checkes available on instances through the features context" do
      expect(object.new.features.some_enabled_feature?).to be(true)
      expect(object.new.features.another_enabled_feature?).to be(true)
    end
  end

  describe "including multiple feature flag modules into an object" do
    let(:more_shared_feature_flags) {
      Module.new do
        extend Featuring::Declarable

        feature :another_enabled_feature, true
      end
    }

    let(:object) {
      Class.new.class_exec(self) do |local|
        include local.shared_feature_flags
        include local.more_shared_feature_flags
      end
    }

    it "can check each flag" do
      expect(object.new.features.some_enabled_feature?).to be(true)
      expect(object.new.features.another_enabled_feature?).to be(true)
    end
  end

  describe "extending an object with feature flags" do
    let(:object) {
      Class.new.class_exec(self) do |local|
        extend Featuring::Declarable
        extend local.shared_feature_flags
      end
    }

    it "is unsupported" do
      expect {
        object
      }.to raise_error(RuntimeError) do |error|
        expect(error.message).to eq("extending classes with feature flags is not currently supported")
      end
    end
  end

  describe "defining feature flags on an object" do
    let(:object) {
      Class.new do
        extend Featuring::Declarable
        feature :some_enabled_feature, true
      end
    }

    it "can define feature flags" do
      expect(object.new.features.some_enabled_feature?).to be(true)
    end
  end
end
