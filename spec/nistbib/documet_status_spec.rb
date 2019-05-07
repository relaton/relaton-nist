RSpec.describe NistBib::DocumentStatus do
  it "raise invalid stage argument error" do
    expect { NistBib::DocumentStatus.new stage: "stage" }.to raise_error ArgumentError
  end

  it "raise invalid substage argument error" do
    expect do
      NistBib::DocumentStatus.new stage: "final", substage: "substage"
    end.to raise_error ArgumentError
  end
end
