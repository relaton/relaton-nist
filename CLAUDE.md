# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

relaton-nist is a Ruby gem that retrieves and manages NIST (National Institute of Standards and Technology) bibliographic metadata as part of the Relaton ecosystem. Data sources include the NIST Cybersecurity Resource Center (CSRC) and the NIST Library (MARC21/MODS XML).

## Development Commands

```bash
# Install dependencies
bundle install

# Run all tests (any of these)
rake
rake spec
bundle exec rspec

# Run a single test file
bundle exec rspec spec/relaton/nist/item_spec.rb

# Run a specific test by line number
bundle exec rspec spec/relaton/nist/item_spec.rb:10

# Interactive console with gem loaded
bin/console

# Lint (uses Ribose OSS rubocop config)
bundle exec rubocop
```

## Architecture

### Lutaml-Model Serialization

All data models inherit from `Lutaml::Model::Serializable` and use declarative attribute/mapping DSL for XML and YAML serialization. The base bibliographic types come from `relaton-bib` (aliased as `Bib`).

**Inheritance chain**: `Bib::Item` → `Relaton::Nist::Item` → `Bibitem` / `Bibdata`
- `Bibitem` includes `Bib::BibitemShared`
- `Bibdata` includes `Bib::BibdataShared`

**NIST-specific models** (under `lib/relaton/nist/`):
- `Ext` — extension block holding doctype, comment period, flavor
- `Date` — adds `abandoned` and `superseded` date types
- `Relation` — adds `obsoletedBy`, `supersedes`, `supersededBy` relation types
- `CommentPeriod` — from/to/extended date ranges
- `Doctype` — currently only `standard`

### Serialization Round-Trip Pattern

Models support `from_xml`/`to_xml` and `from_yaml`/`to_yaml`. Tests verify round-trip fidelity by parsing a fixture, re-serializing, and comparing output to input.

### XML Schema Validation

RNG (Relax NG) schemas in `grammars/` validate XML output. Tests use the `jing` gem:
```ruby
schema = Jing.new("grammars/relaton-nist-compile.rng")
errors = schema.validate(file)
```
`relaton-nist-compile.rng` is the top-level schema that includes `relaton-nist.rng` and `basicdoc.rng`.

### HTTP Recording

Tests use VCR with WebMock. Cassettes are stored in `spec/vcr_cassettes/` and re-record every 7 days.

## Key Dependencies

- `relaton-bib` — base bibliographic models and shared mixins
- `loc_mods` — MODS (Metadata Object Description Schema) XML parsing
- `pubid` — NIST publication ID parsing
- `relaton-index` — index/search utilities

## Code Style

RuboCop config inherits from the Ribose OSS style guide. Target Ruby version is 2.7.
