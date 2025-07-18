lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "que/scheduler/version"

Gem::Specification.new do |spec|
  # rubocop:disable Layout/HashAlignment
  spec.name          = "que-scheduler"
  spec.version       = Que::Scheduler::VERSION
  spec.authors       = ["Harry Lascelles"]
  spec.email         = ["harry@harrylascelles.com"]

  spec.summary       = "A cron scheduler for Que"
  spec.description   = "A lightweight cron scheduler for the Que async job worker"
  spec.homepage      = "https://github.com/hlascelles/que-scheduler"
  spec.license       = "MIT"
  spec.metadata      = {
    "homepage_uri"      => "https://github.com/hlascelles/que-scheduler",
    "documentation_uri" => "https://github.com/hlascelles/que-scheduler",
    "changelog_uri"     => "https://github.com/hlascelles/que-scheduler/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/hlascelles/que-scheduler/",
    "bug_tracker_uri"   => "https://github.com/hlascelles/que-scheduler/issues",
    "rubygems_mfa_required" => "true",
  }

  spec.files = Dir["{lib}/**/*"] + ["README.md"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "fugit", "~> 1.1", ">= 1.11.1" # 1.11.1 prevents https://github.com/floraison/fugit/issues/104
  spec.add_dependency "hashie", ">= 3", "< 6"
  spec.add_dependency "que", ">= 2.0", "< 3.0"

  spec.add_development_dependency "activerecord", ">= 5.0", "< 8.0"
  spec.add_development_dependency "appraisal"
  # Ruby 3.4 needs this gem for specs, otherwise we see "cannot load such file -- base64"
  spec.add_development_dependency "base64"
  spec.add_development_dependency "climate_control"
  spec.add_development_dependency "combustion"
  spec.add_development_dependency "coveralls_reborn"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "dememoize"
  spec.add_development_dependency "fasterer"
  # Ruby 3.4 needs this gem for specs, otherwise we see "cannot load such file -- mutex_m"
  spec.add_development_dependency "mutex_m"
  spec.add_development_dependency "pg", ">= 1.0"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "psych", "3.1.0" # Default version in dev ruby
  spec.add_development_dependency "rake"
  spec.add_development_dependency "reek"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rake", "> 0.7.0" # as plugin
  spec.add_development_dependency "rubocop-rspec", "> 3.5.0" # as plugin
  spec.add_development_dependency "sqlite3", ">= 1.3"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "zonebie"
  # rubocop:enable Layout/HashAlignment
end
