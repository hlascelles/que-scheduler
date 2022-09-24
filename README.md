que-scheduler
================

[![Gem Version](https://badge.fury.io/rb/que-scheduler.svg)](https://badge.fury.io/rb/que-scheduler)
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
1. Specify a schedule in a yml file or programmatically (see below). The default location that 
que-scheduler will look for it is `config/que_schedule.yml`. The format is essentially the same as
resque-scheduler files, but with additional features.

1. Add a migration to start the job scheduler and prepare the audit table. Note that this migration 
   will fail if Que is set to execute jobs synchronously, i.e. `Que::Job.run_synchronously = true`.

    ```ruby
    class CreateQueSchedulerSchema < ActiveRecord::Migration
      def change
        Que::Scheduler::Migrations.migrate!(version: 7)
      end
    end
    ```
    
## Schedule configuration

The schedule file should be placed here: `config/que_schedule.yml`. Alternatively if you
wish to generate the configuration dynamically, you can set it directly using an initializer
(see "Gem configuration" below).

The file is a list of que job classes with arguments and a schedule frequency (in crontab 
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
  
# Specify array job arguments
SendOrders:
  cron: "0 0 * * *"
  args: ['open']

# Specify hash job arguments. Note, this appears as a single hash to `run`, not as kwargs.
SendPreorders:
  cron: "0 0 * * *"
  args:
    order_type: special
  
# Specify a single nil argument
SendPostorders:
  cron: "0 0 * * *"
  args: ~ # See https://stackoverflow.com/a/51990876/1267203
  
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
  
# Ensure you never miss a job, even after downtime, by using "schedule_type: every_event"
DailyBatchReport:
  cron: "0 3 * * *"
  # This job will be run every day at 03:00 as normal.
  # However, the "schedule_type: every_event" setting below will ensure that if workers are offline
  # for any amount of time then the backlog will always be enqueued on recovery.
  # See "Schedule types" below for more information.
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
  startup. This `schedule_type` should be used for regular batch jobs that need to know which time
  they are running a batch for. The job will always be scheduled with an ISO8601 string of the cron 
  that matched as the first argument. 
  
  An example would be an eventing DailyReportJob which summarises a day's sales. If no jobs run for
  a few days due to a technical failure, then on recovery a report would still be needed for each 
  individual day. "schedule_type: every_event" would ensure this happens.
  
  This feature ensures that jobs which *must run* for a certain cron match will always eventually 
  execute, even after a total system crash, or even a DB backup restore.

## Gem configuration

You can configure some aspects of the gem with a config block (eg in a Rails initializer). 
The default is given below. You can omit any configuration sections you are not intending to change.
It is quite likely you won't have to create this config at all.

```ruby
Que::Scheduler.configure do |config|
  # The location of the schedule yaml file.
  config.schedule_location = ENV.fetch("QUE_SCHEDULER_CONFIG_LOCATION", "config/que_schedule.yml")

  # The schedule as a hash. You can use this if you want to build the schedule yourself at runtime.
  # This will override the above value if provided.
  config.schedule = {
    SpecifiedByHashTestJob: {
      cron: "02 11 * * *"
    }
  }
  
  # The transaction block adapter. By default, que-scheduler uses the one supplied by que.
  # However if, for example, you rely on listeners to ActiveRecord's exact `transaction` method, or 
  # Sequel's DB.after_commit helper, then you can supply it here.
  config.transaction_adapter = ::Que.method(:transaction)

  # Which queue name the que-scheduler job should self-schedule on. Typically this is the default
  # queue of que, which has a different name in Que 0.x ("") and 1.x ("default").
  # It *must* be the "highest throughput" queue - do not work the scheduler on a "long 
  # running jobs" queue. It is very unlikely you will want to change this. 
  config.que_scheduler_queue = ENV.fetch("QUE_SCHEDULER_QUEUE", "" or "default")
  
  # If que-scheduler is being used with Rails, then it will inherit the time zone from that 
  # framework, and you can leave the value as nil as shown below. However, if you are not using
  # Rails, you may need to set the time zone here. If que-scheduler cannot determine the time zone
  # it will yield an error prompting you for action.
  # If you need to set a value, use the string representation:
  # eg: config.time_zone = "Europe/London"
  config.time_zone = nil
end
```

## Scheduler Audit

An audit table `que_scheduler_audit` is written to by the scheduler to keep a history of when the 
scheduler ran to calculate what was necessary to run (if anything). It is created by the included 
migration tasks.

Additionally, there is the audit table `que_scheduler_audit_enqueued`. This logs every job that 
the scheduler enqueues.

que-scheduler comes with the `QueSchedulerAuditClearDownJob` job built in that you can optionally
schedule to clear down audit rows if you don't need to retain them indefinitely. You should add this
to your own scheduler config yaml.

For example:

```yaml
# This will clear down the oldest que-scheduler audit rows. Since que-scheduler
# runs approximately every minute, 129600 is 90 days.
Que::Scheduler::Jobs::QueSchedulerAuditClearDownJob:
  cron: "0 0 * * *"
  args:
    retain_row_count: 129600
```

## Required migrations

When there is a major version (breaking) change, a migration should be run in. The version of the 
latest migration proceeds at a faster rate than the version of the gem. eg If the gem is on version
3 then the migrations may be on version 6). 

To run in all the migrations required up to a number, just migrate to that number with one line, and
it will perform all the intermediary steps. 

ie, This will perform all migrations necessary up to the latest version, skipping any already 
performed.

```ruby
class CreateQueSchedulerSchema < ActiveRecord::Migration
  def change
    Que::Scheduler::Migrations.migrate!(version: 7)
  end
end
```

The changes in past migrations were: 

| Version | Changes                                                                         |
|:-------:|---------------------------------------------------------------------------------|
|    1    | Enqueued the main Que::Scheduler. This is the job that performs the scheduling. |
|    2    | Added the audit table `que_scheduler_audit`.                                    |
|    3    | Added the audit table `que_scheduler_audit_enqueued`.                           |
|    4    | Updated the the audit tables to use bigints                                     |
|    5    | Dropped an unnecessary index                                                    |
|    6    | Enforced single scheduler job at the trigger level                              |

The changes to the DB ([DDL](https://en.wikipedia.org/wiki/Data_definition_language)) are all 
captured in the structure.sql so will be re-run in correctly if squashed - except for the actual 
scheduling of the job itself (as that is [DML](https://en.wikipedia.org/wiki/Data_manipulation_language)).
If you squash your migrations make sure this is added as the final line:

```ruby
Que::Scheduler::Migrations.reenqueue_scheduler_if_missing
```

## HA Redundancy and DB restores

Because of the way que-scheduler works, it requires no additional processes. It is, itself, a Que job.
As long as there are Que workers functioning, then jobs will continue to be scheduled correctly. There
are no HA concerns to worry about and no namespace collisions between different databases. 

Additionally, like Que, when your database is backed up, your scheduling state is stored too. If your 
workers are down for an extended period, or a DB restore is performed, the scheduler will always be 
in a coherent state with the rest of your database.

## Concurrent scheduler detection

No matter how many tasks you have defined in your schedule, you will only ever need one que-scheduler
job enqueued. que-scheduler knows this, and there are DB constraints in place to ensure there is
only ever exactly one scheduler job.

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
   
## Testing Configuration

You can add tests to validate your configuration during the spec phase. This will perform a variety 
of sanity checks and ensure that:

1. The yml is present and valid
1. The job classes exist and are descendants of Que::Job
1. The cron fields are present and valid
1. The queues (if present) are strings
1. The priorities (if present) are integers
1. The schedule_types are known

```ruby

  describe 'check que_schedule.yml' do
    it 'loads the schedule from the default location' do
      # Will raise an error if any config is invalid
      expect(Que::Scheduler.schedule).not_to be nil
    end
  end
```

## Error Notification

If there is an error during scheduling, que-scheduler will report it using the [standard que error
notifier](https://github.com/chanks/que/blob/master/docs/error_handling.md#error-notifications).
The scheduler will then continue to retry indefinitely.

## Upgrading

que-scheduler uses [semantic versioning](https://semver.org/), so major version changes will usually 
require additional actions to be taken upgrading from one major version to another. 

## Changelog

A full changelog can be found here: [CHANGELOG.md](https://github.com/hlascelles/que-scheduler/blob/master/CHANGELOG.md)

## System requirements

Your [postgres](https://www.postgresql.org/) database must be at least version 9.6.0.

The latest version of que-scheduler supports Ruby 2.7 and above.
que-scheduler versions below 4.2.3 work with Ruby 2.5 and Ruby 2.6.

Using que 0.x with Rails 6 needs a patch to support it. 
See the patch and how to use it here: https://github.com/que-rb/que/issues/247#issuecomment-595258236
If that patch is included then que-scheduler will work. This setup is tested, but is not supported.

## Inspiration

This gem was inspired by the makers of the excellent [Que](https://github.com/chanks/que) job scheduler gem. 

## Contributors

* @bnauta
* @bjeanes
* @JackDanger
* @jish
* @joehorsnell
* @krzyzak
* @papodaca
* @ajoneil
* @ippachi
* @milgner
