que-scheduler
================

[![Gem Version](https://badge.fury.io/rb/que-scheduler.svg)](https://badge.fury.io/rb/que-scheduler)
[![Build Status](https://travis-ci.org/hlascelles/que-scheduler.svg?branch=master)](https://travis-ci.org/hlascelles/que-scheduler)
[![Dependency Status](https://gemnasium.com/badges/github.com/hlascelles/que-scheduler.svg)](https://gemnasium.com/github.com/hlascelles/que-scheduler)
[![Coverage Status](https://coveralls.io/repos/github/hlascelles/que-scheduler/badge.svg?branch=master)](https://coveralls.io/github/hlascelles/que-scheduler?branch=master)
[![Code Climate Maintainability](https://api.codeclimate.com/v1/badges/710d2fc5202f95d76e8a/maintainability)](https://codeclimate.com/github/hlascelles/que-scheduler/maintainability)

### Description

que-scheduler is an extension to [Que](https://github.com/chanks/que) that adds support for scheduling 
items using a cron style configuration file. It works by running as a que job itself, determining what 
needs to be run, enqueueing those jobs, then enqueueing itself to check again later.

### Installation

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
    
### Schedule configuration

The schedule file is a list of que job classes with arguments and a schedule frequency (in crontab 
syntax). The format is a superset of the resque-scheduler config format, so it they can be used
as-is with no modification, assuming the job classes are migrated from Resque to Que.

It has one additional feature, `unmissable: true`. This is set on a job that must be run for every 
single matching cron time that goes by, even if the system is offline over more than one match. To better process these unmissable jobs, they are always enqueued with the first 
argument being the time that they were supposed to be processed.  
 
For example:

```yaml
CancelAbandonedOrders:
  cron: "*/5 * * * *"

queue_documents_for_indexing:
  cron: "0 0 * * *"
  # By default the job name (hash key) will be taken as worker class name.
  # If you want to have a different job name and class name, provide the 'class' option
  class: "QueueDocuments"
  queue: high
  args: ['reports', 'expenses']

clear_leaderboards_contributors:
  cron: "30 6 * * 1"
  class: "ClearLeaderboards"
  queue: low
  args: contributors
  
DailyBatchReport:
  cron: "0 3 * * *"
  # This job will be run every day, and if workers are offline for several days, then the backlog
  # will all be scheduled when they are restored, each with that events timestamp as the first arg.
  unmissable: true
```

### Environment Variables

You can configure some aspects of the gem with environment variables.

* `QUE_SCHEDULER_CONFIG_LOCATION` - The location of the schedule configuration (default `config/que_schedule.yml`)

### Redundancy and Fail-Over

Because of the way que-scheduler works, it requires no additional processes. It is, itself, a Que job.
As long as there are Que workers functioning, then jobs will continue to be scheduled correctly. There
are no HA concerns to worry about and no namespace collisions between different databases. 

Additionally, like Que, when your database is backed up, your scheduling state is stored too.

### How it works

que-scheduler is a job that reads a config file, enqueues any jobs it determines that need to be run,
then reschedules itself. The flow is as follows:

1. The que-scheduler job runs for the very first time.
1. que-scheduler loads the schedule config file. It will not schedule any other jobs, except itself, as it has never run before.
1. Some time later it runs again. It knows what jobs it should be monitoring, and notices that some have are due. It enqueues those jobs and then itself. Repeat.
1. After a deploy that changes the config, the job notices any new jobs to schedule, and knows which ones to forget. It does not need to be re-enqueued or restarted.

### Thanks

This gem was inspired by the makers of the excellent [Que](https://github.com/chanks/que) job scheduler gem. 
