# Test New Rails install

This folder contains all the files and a script to ensure that installing que-scheduler on a new
Rails install works without errors, including an initial migration.

First start a postgres docker container with:

`docker run -p 5430:5432 postgres:9.6.0`

Then run: 

`RAILS_VERSION=5.2.4.4 QUE_VERSION=2.4.1 ./install_test.sh`
