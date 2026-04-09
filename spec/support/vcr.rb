require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.default_cassette_options = {
    clean_outdated_http_interactions: true,
    re_record_interval: 7 * 24 * 3600,
    record: :once,
    preserve_exact_body_bytes: true,
  }
  config.hook_into :webmock
  config.configure_rspec_metadata!
  $ignore_pubs_export = true # rubocop:disable Style/GlobalVars
  config.ignore_request do |request|
    path = URI(request.uri).path
    path.end_with?("index-v1.zip") || (path.include?("pubs-export") && $ignore_pubs_export) # rubocop:disable Style/GlobalVars
  end
end
