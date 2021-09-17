# frozen_string_literal: true

require "featuring"

RSpec.describe "default feature flags persistence" do
  let(:object) {
    Class.new.tap do |object|
      object.class_eval do
        extend Featuring::Declarable
        feature :some_feature
      end
    end
  }

  it "does not allow features to be enabled" do
    expect {
      object.new.features.enable :some_feature
    }.to raise_error(NoMethodError)
  end

  it "does not allow features to be disabled" do
    expect {
      object.new.features.disable :some_feature
    }.to raise_error(NoMethodError)
  end

  it "does not allow features to be set" do
    expect {
      object.new.features.set :some_feature, true
    }.to raise_error(NoMethodError)
  end

  it "does not allow features to be persisted" do
    expect {
      object.new.features.persist :some_feature
    }.to raise_error(NoMethodError)
  end
end
