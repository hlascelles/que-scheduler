
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
  spec.homepage      = 'https://github.com/hlascelles/que-scheduler'
  spec.license       = 'MIT'

  spec.files = Dir['{lib}/**/*'] + ['README.md']
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 4.0'
  spec.add_dependency 'backports', '~> 3.10'
  spec.add_dependency 'fugit', '~> 1'
  spec.add_dependency 'hashie', '~> 3'
  spec.add_dependency 'que', '~> 0.10'
end
