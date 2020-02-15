RSpec.describe RelatonNist::Hit do
  it "returns sort value for draft (withdrawn)" do
    hit = RelatonNist::Hit.new status: "draft (obsolete)"
    expect(hit.sort_value).to eq 1
  end
end
