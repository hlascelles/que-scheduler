que-scheduler
================

[![Gem Version](https://badge.fury.io/rb/que-scheduler.svg)](https://badge.fury.io/rb/que-scheduler)
[![Build Status](https://travis-ci.org/hlascelles/que-scheduler.svg?branch=master)](https://travis-ci.org/hlascelles/que-scheduler)
[![Dependency Status](https://gemnasium.com/badges/github.com/hlascelles/que-scheduler.svg)](https://gemnasium.com/github.com/hlascelles/que-scheduler)
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
1. Specify a schedule config in a yml file (see below). The default location that que-scheduler will 
look for it is `config/que_schedule.yml`. They are essentially the same as resque-scheduler config
files, but with additional features.

1. Add a migration to start the job scheduler.

    ```ruby
    Que::Scheduler::SchedulerJob.enqueue
    ```
    
## Schedule configuration

The schedule file is a list of que job classes with arguments and a schedule frequency (in crontab 
syntax). The format is similar to the resque-scheduler config format, though priorities must be supplied as
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

# Specify the job_class, using any name for the key.
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
  
# Use simpler cron syntax.
SendBilling:
  cron: "@daily"

# Altogether now
all_args_job:
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

1. `default` - This job will be scheduled when a worker becomes available. If multiple cron times 
  go by during an extended period of downtime then only one job will be enqueued. This is closer to 
  how ordinary cron works.
1. `every_event` - This job will always be scheduled with an ISO8601 time as the first argument. 
  If multiple cron times go by during an extended period of downtime, then a job will be scheduled 
  for every one missed. This `schedule_type` should be used for daily batch jobs that need to know 
  which day they are running a batch for.

## Environment Variables

You can configure some aspects of the gem with environment variables.

* `QUE_SCHEDULER_CONFIG_LOCATION` - The location of the schedule configuration (default `config/que_schedule.yml`)

## HA Redundancy and DB restores

Because of the way que-scheduler works, it requires no additional processes. It is, itself, a Que job.
As long as there are Que workers functioning, then jobs will continue to be scheduled correctly. There
are no HA concerns to worry about and no namespace collisions between different databases. 

Additionally, like Que, when your database is backed up, your scheduling state is stored too. If your 
workers are down for an extended period, or a DB restore is performed, the scheduler will always be 
in a coherent state with the rest of your database.

## Multiple scheduler detection

No matter how many tasks you have defined in your config, you will only ever need one que-scheduler
job enqueued. que-scheduler knows this, and it will check before performing any operations that 
there is only one of itself present.

## How it works

que-scheduler is a job that reads a config file, enqueues any jobs it determines that need to be run,
then reschedules itself. The flow is as follows:

1. The que-scheduler job runs for the very first time.
1. que-scheduler loads the schedule config file. It will not schedule any other jobs, except itself, as it has never run before.
1. Some time later it runs again. It knows what jobs it should be monitoring, and notices that some have are due. It enqueues those jobs and then itself. Repeat.
1. After a deploy that changes the config, the job notices any new jobs to schedule, and knows which ones to forget. It does not need to be re-enqueued or restarted.

## Inspiration

This gem was inspired by the makers of the excellent [Que](https://github.com/chanks/que) job scheduler gem. 

## Contributors

* @jish
* @joehorsnell
