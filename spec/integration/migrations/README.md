# Test migrations between Que versions

This folder contains all the files and a script to ensure that upgrading Que works concerning migrations.
See this issue for more details: https://github.com/hlascelles/que-scheduler/issues/381

First start a postgres docker container with:

`docker run -p 5430:5432 postgres:9.6.0`

Then run: 

`./migrate_test.sh`
