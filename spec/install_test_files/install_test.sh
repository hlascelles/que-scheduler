#!/usr/bin/env bash
set -euox pipefail

echo "*******************************************************************************************"
echo "Start a docker container with: docker run -p 5430:5432 postgres:9.5.0 then run this script."
echo "*******************************************************************************************"

rm -rf target
mkdir -p target/db/migrate
mkdir -p target/config
cp Gemfile target
cd target
bundle install
bundle exec rails _${RAILS_VERSION}_ new . --skip-bundle --skip-gemfile --api --skip-sprockets -T
cp ../create_que_scheduler_schema.rb db/migrate/20191026153028_create_que_scheduler_schema.rb
cp ../database.yml config
bundle exec rake db:create db:migrate --trace
bundle exec rake db:drop
