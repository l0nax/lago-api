# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::InvoiceCustomSections::CreateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:code).of_type("String!")
    expect(subject).to accept_argument(:description).of_type("String")
    expect(subject).to accept_argument(:details).of_type("String")
    expect(subject).to accept_argument(:display_name).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String!")
    expect(subject).to accept_argument(:selected).of_type("Boolean")
  end
end
