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
  }

  spec.files = Dir["{lib}/**/*"] + ["README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 4.0"
  spec.add_dependency "fugit", "~> 1.1", ">= 1.1.8" # 1.1.8 fixes "disallow zero months in cron"
  spec.add_dependency "hashie", ">= 3", "< 5"
  spec.add_dependency "que", ">= 0.12", "<= 1.0.0.beta4"

  spec.add_development_dependency "activerecord", ">= 4.0"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "combustion"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "fasterer"
  spec.add_development_dependency "pg", "~> 0.21"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "reek"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop", "0.87.1" # Hound version
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "sqlite3", ">= 1.3"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "zonebie"
  # rubocop:enable Layout/HashAlignment
end
