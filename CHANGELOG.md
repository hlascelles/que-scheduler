## Unreleased

* Switched to use DB time to find "now" so as to match que queries
* Added more tests for various ways of supplying args

## 1.0.3 (2018-03-15)

* Enforced a minimum version of `et-orbi` to supply `#to_local_time` methods. Thanks to @jish.
* Clarified config syntax

## 1.0.2 (2018-01-15)

* Added ORM adapter layer to allow use of [Sequel](https://github.com/jeremyevans/sequel)

## 1.0.1 (2018-01-06)

* Refactoring and code cleanup

## 1.0.0 (2017-12-19)

* Remove legacy config keys

## 0.10.1 (2017-12-03)

* Added `schedule_type` config key.

## 0.9.1 (2017-12-03)

* Added a `::Rails::Engine` to ensure the schedule config is validated at worker start time

## 0.8.1 (2017-11-18)

* Scheduler config check for valid `Que::Job` subclasses

## 0.8.0 (2017-11-11)

* Added multiple scheduler job detection
* Added more tests

## 0.7.0 (2017-11-05)

* Update dependencies
* Added more tests
* Add additional checks for worker clock skew

## 0.6.0 (2017-11-05)

* Formalised all internal args as Hashies
* Enforced correct yml values

## 0.5.0 (2017-11-05)

* Refactored to take a hash as SchedulerJob args
* Formalised `SchedulerJob` args as a `Hashie`
* Formalised using ISO8601 everywhere

## 0.4.0 (2017-10-27)

* Added CI Travis builds

## 0.3.0 (2017-10-27)

* Added more tests and refactored

## 0.2.0 (2017-10-27)

* Added `README.md`

## 0.1.0 (2017-10-27)

* First release.
