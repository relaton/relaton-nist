lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "relaton_nist/version"

Gem::Specification.new do |spec|
  spec.name          = "relaton-nist"
  spec.version       = RelatonNist::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "RelatonNist: retrive NIST standards."
  spec.description   = "RelatonNist: retrive NIST standards."
  spec.homepage      = "https://github.com/metanorma/relaton-nist"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.add_dependency "base64"
  spec.add_dependency "loc_mods", "~> 0.2.0"
  spec.add_dependency "pubid", "~> 0.1.0"
  spec.add_dependency "relaton-bib", "~> 1.20.0"
  spec.add_dependency "relaton-index", "~> 0.2.0"
  spec.add_dependency "rubyzip"
end
