lib = File.expand_path("../lib", __FILE__)
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
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.add_development_dependency "byebug"
  spec.add_development_dependency "debase"
  spec.add_development_dependency "equivalent-xml", "~> 0.6"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "ruby-debug-ide"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "ruby-jing"

  spec.add_dependency "relaton-bib", "~> 0.4.0"
  spec.add_dependency "rubyzip"
end
