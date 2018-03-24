
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'que/scheduler/version'

Gem::Specification.new do |spec|
  spec.name          = 'que-scheduler'
  spec.version       = Que::Scheduler::VERSION
  spec.authors       = ['Harry Lascelles']
  spec.email         = ['harry@harrylascelles.com']

  spec.summary       = 'A cron scheduler for Que'
  spec.description   = 'A lightweight cron scheduler for the Que async job worker'
  spec.homepage      = 'https://github.com/hlascelles/que-scheduler'
  spec.license       = 'MIT'

  spec.files = Dir['{lib}/**/*'] + ['README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 3.0'
  spec.add_dependency 'backports', '~> 3.10'
  spec.add_dependency 'et-orbi', '> 1.0.5' # need the `#to_local_time` method
  spec.add_dependency 'rufus-scheduler', '~> 3'
  spec.add_dependency 'hashie', '~> 3'
  spec.add_dependency 'que', '~> 0.10'

  spec.add_development_dependency 'activerecord', '>= 3.0'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'combustion'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'que-testing'
  spec.add_development_dependency 'railties', '>= 3.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'reek'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'sequel', '>= 4.0'
  spec.add_development_dependency 'sqlite3', '>= 1.3'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'zonebie'
end
