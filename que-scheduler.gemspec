
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'que/scheduler/version'

Gem::Specification.new do |spec|
  spec.name          = 'que-scheduler'
  spec.version       = Que::Scheduler::VERSION
  spec.authors       = ['Harry Lascelles']
  spec.email         = ['harry@harrylascelles.com']

  spec.summary       = 'A cron scheduler for Que'
  spec.description   = 'A lightweight cron scheduler for the async job worker Que'
  spec.homepage      = 'https://rubygems.org/gems/que-scheduler'
  spec.license       = 'MIT'

  spec.files = Dir['{lib}/**/*'] + ['README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 3.0'
  spec.add_dependency 'fugit', '~> 1.0'
  spec.add_dependency 'que', '~> 0.12'

  spec.add_development_dependency 'activesupport', '>= 4.0'
  spec.add_development_dependency 'bundler', '~> 1.15'
  spec.add_development_dependency 'pry-byebug', '~> 3.0'
  spec.add_development_dependency 'que-testing', '~> 0.1'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.51'
  spec.add_development_dependency 'timecop', '~> 0.7'
  spec.add_development_dependency 'zonebie', '~> 0.6'
end
