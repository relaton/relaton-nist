require "webmock/rspec"
require "zip"
require "yaml"
require "json"

INDEX_ZIP_PATH = File.join(__dir__, "..", "fixtures", "index-v1.zip")
PUBS_EXPORT_ZIP_PATH = File.join(__dir__, "..", "fixtures", "pubs-export.zip")

RSpec.configure do |config|
  config.before(:suite) do
    # Parse index YAML from fixture zip once
    yaml = Zip::File.open(INDEX_ZIP_PATH) do |zip|
      zip.first.get_input_stream.read
    end
    index_data = YAML.safe_load(yaml, permitted_classes: [Symbol])

    # Create a Type instance with data pre-loaded (no URL, no I/O)
    type = Relaton::Index::Type.new(:nist, nil, "index-v1.yaml")
    type.instance_variable_set(:@index, index_data)
    type.define_singleton_method(:actual?) { |**_args| true }

    # Inject into pool so find_or_create(:nist, ...) returns this instance
    Relaton::Index.pool.instance_variable_get(:@pool)[:NIST] = type

    # Pre-load PubsExport data from fixture zip
    pubs_data = Zip::File.open(PUBS_EXPORT_ZIP_PATH) do |zf|
      JSON.parse(zf.first.get_input_stream.read)
    end
    Relaton::Nist::PubsExport.instance.instance_variable_set(:@data, pubs_data)
  end

  config.before(:each) do
    WebMock.reset!
    WebMock.disable_net_connect!
  end
end
