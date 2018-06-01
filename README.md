que-scheduler
================

[![Gem Version](https://badge.fury.io/rb/que-scheduler.svg)](https://badge.fury.io/rb/que-scheduler)
[![Build Status](https://travis-ci.org/hlascelles/que-scheduler.svg?branch=master)](https://travis-ci.org/hlascelles/que-scheduler)
[![Coverage Status](https://coveralls.io/repos/github/hlascelles/que-scheduler/badge.svg?branch=master)](https://coveralls.io/github/hlascelles/que-scheduler?branch=master)
[![Code Climate Maintainability](https://api.codeclimate.com/v1/badges/710d2fc5202f95d76e8a/maintainability)](https://codeclimate.com/github/hlascelles/que-scheduler/maintainability)

## Description

que-scheduler is an extension to [Que](https://github.com/chanks/que) that adds support for scheduling 
items using a cron style configuration file. It works by running as a que job itself, determining what 
needs to be run, enqueueing those jobs, then enqueueing itself to check again later.

## Installation

1. To install, add the gem to your Gemfile:
    ```ruby
    gem 'que-scheduler'
    ```
1. Specify a schedule in a yml file (see below). The default location that que-scheduler will 
look for it is `config/que_schedule.yml`. They are essentially the same as resque-scheduler
files, but with additional features.

1. Add a migration to start the job scheduler and prepare the audit table.

    ```ruby
    class CreateQueSchedulerSchema < ActiveRecord::Migration
      def change
        Que::Scheduler::Migrations.migrate!(version: 4)
      end
    end
    ```
    
## Schedule configuration

The schedule file is a list of que job classes with arguments and a schedule frequency (in crontab 
syntax). The format is similar to the resque-scheduler format, though priorities must be supplied as
integers, and job classes must be migrated from Resque to Que. Cron syntax can be anything
understood by [fugit](https://github.com/floraison/fugit#fugitcron).

It has one additional feature, `schedule_type: every_event`. This is set on a job that must be run for every 
single matching cron time that goes by, even if the system is offline over more than one match. 
To better process these `every_event` jobs, they are always enqueued with the first 
argument being the time that they were supposed to be processed.  
 
For example:

```yaml
CancelAbandonedOrders:
  cron: "*/5 * * * *"

# Specify the job_class, using any name for the key
queue_documents_for_indexing:
  cron: "0 0 * * *"
  class: QueueDocuments
  
# Specify the job queue
ReportOrders:
  cron: "0 0 * * *"
  queue: reporting

# Specify the job priority using Que's number system
BatchOrders:
  cron: "0 0 * * *"
  priority: 25
  
# Specify job arguments
SendOrders:
  cron: "0 0 * * *"
  args: ['open']
  
# Use simpler cron syntax
SendBilling:
  cron: "@daily"
  
# Use timezone cron syntax
SendCoupons:
  cron: "0 7 * * * America/Los_Angeles"

# Altogether now
all_options_job:
  cron: "0 0 * * *"
  class: QueueDocuments
  queue: reporting
  priority: 25
  args: ['open']
  
# Ensure you never miss a job, even after downtime
DailyBatchReport:
  cron: "0 3 * * *"
  # This job will be run every day. If workers are offline for several days, then the backlog
  # will all be scheduled when they are restored, each with that event's timestamp as the first arg.
  schedule_type: every_event
```

## Schedule types

A job can have a `schedule_type` assigned to it. Valid values are:

1. `default` - This job will be scheduled in a manner closer to resque-scheduler. If multiple cron
  times go by during an extended period of downtime (eg a long maintenance window) then only one job
  will be enqueued when the system starts back up. Multiple missed events are coalesced. This mimics
  the way resque-scheduler would perform if it were taken down for some time.
1. `every_event` - Every cron match will result in a job being scheduled. If multiple cron times go 
  by during an extended period of downtime, then a job will be scheduled for every one missed on 
  startup. This `schedule_type` should be used for daily batch jobs that need to know which day 
  they are running a batch for. The job will always be scheduled with an ISO8601 string of the cron 
  that matched as the first argument. 
   
   This feature ensures that jobs which *must run* for a certain cron match will always eventually 
  execute, even after a total system crash, or even a DB backup restore.

## Gem configuration

You can configure some aspects of the gem with an initializer. The default is given below.

```ruby
Que::Scheduler.configure do |config|
  # The location of the schedule yaml file.
  config.schedule_location = ENV.fetch('QUE_SCHEDULER_CONFIG_LOCATION', 'config/que_schedule.yml')
  
  # Specify a transaction block adapter. By default, que-scheduler uses the one supplied by que.
  # However, if, for example you rely on listeners to ActiveRecord's exact `transaction` method, or 
  # Sequel's DB.after_commit helper, then you can supply it here.
  config.transaction_adapter = ::Que.method(:transaction)
end

```

## Scheduler Audit

An audit table _que_scheduler_audit_ is written to by the scheduler to keep a history of what jobs 
were enqueued when. It is created by the included migration tasks.

## HA Redundancy and DB restores

Because of the way que-scheduler works, it requires no additional processes. It is, itself, a Que job.
As long as there are Que workers functioning, then jobs will continue to be scheduled correctly. There
are no HA concerns to worry about and no namespace collisions between different databases. 

Additionally, like Que, when your database is backed up, your scheduling state is stored too. If your 
workers are down for an extended period, or a DB restore is performed, the scheduler will always be 
in a coherent state with the rest of your database.

## Concurrent scheduler detection

No matter how many tasks you have defined in your schedule, you will only ever need one que-scheduler
job enqueued. que-scheduler knows this, and it will check before performing any operations that 
there is only one of itself present.

It also follows que job design [best practices](https://github.com/chanks/que/blob/master/docs/writing_reliable_jobs.md),
using ACID guarantees, to ensure that it will never run multiple times. If the scheduler crashes for any reason,
it will rollback correctly and try again. It won't schedule jobs twice for a cron match.

## How it works

que-scheduler is a job that reads a schedule file, enqueues any jobs it determines that need to be run,
then reschedules itself. The flow is as follows:

1. The que-scheduler job runs for the very first time.
1. que-scheduler loads the schedule file. It will not schedule any other jobs, except itself, 
   as it has never run before.
1. Some time later it runs again. It knows what jobs it should be monitoring, and notices that some 
   have are due. It enqueues those jobs and then itself. Repeat.
1. After a deploy that changes the schedule, the job notices any new jobs to schedule, and knows which
   ones to forget. It does not need to be re-enqueued or restarted.
   
## DB Migrations

When there is a major version (breaking) change, a migration should be run in. The version of the 
migration proceeds at a faster rate than the version of the gem. To run in all the migrations required
up to a number, just migrate to that number with one line, and it will perform all the intermediary steps. 

ie, `Que::Scheduler::Migrations.migrate!(version: 4)` will perform all migrations necessary to 
reach migration version `4`.

As of migration `4`, two elements are added to the DB for que-scheduler to run. 

1. The first is the scheduler job itself, which runs forever, re-enqueuing itself to performs its 
   duties.
1. The second part comprises the audit table `que_scheduler_audit` and the "enqueued" table 
  `que_scheduler_audit`. The first tracks when the scheduler calculated what was necessary to run 
  (if anything). The second then logs every job that the scheduler enqueues. 

## Upgrading

que-scheduler uses [semantic versioning](https://semver.org/), so major version changes will usually 
require additional actions to be taken upgrading from one major version to another. 

Major feature changes are listed below. The full 
[CHANGELOG](https://github.com/hlascelles/que-scheduler/blob/master/CHANGELOG.md) can be found in 
the root of the project. 

#### Versions 3.x 
  - Addition of a config initializer.
  - Addition of numerous extra columns to the audit table.
  - Required cumulative migration: `Que::Scheduler::Migrations.migrate!(version: 4)`
#### Versions 2.x 
  - Introduction of the audit table.
  - Support for older versions of postgres
  - Required cumulative migration: `Que::Scheduler::Migrations.migrate!(version: 3)`
#### Versions 1.x
  - Sequel support
  - Config specified Timezone support
  - Required migration adding the initial job: `Que::Scheduler::SchedulerJob.enqueue`
#### Versions 0.x
  - The first public release. 
  - Required migration adding the initial job: `Que::Scheduler::SchedulerJob.enqueue`
   
## System requirements

Your [postgres](https://www.postgresql.org/) database must be at least version 9.4.0.

## Inspiration

This gem was inspired by the makers of the excellent [Que](https://github.com/chanks/que) job scheduler gem. 

## Contributors

* @jish
* @joehorsnell
