#!/usr/bin/env bash
set -euox pipefail

echo "*******************************************************************************************"
echo "Start a docker container with: docker run -p 5430:5432 postgres:9.6.0 then run this script."
echo "*******************************************************************************************"

rm -rf target
mkdir -p target/db/migrate
mkdir -p target/config
cd target
export RAILS_VERSION=7.2.2
export QUE_VERSION=2.1
bundle install
bundle exec rails _${RAILS_VERSION}_ new . --skip-bundle --skip-gemfile --api --skip-sprockets -T
rm -rf .git
rm .gitignore

echo "gem 'que', '~> ${QUE_VERSION}'" >> Gemfile
echo "gem 'que-scheduler', path: '../../../../'" >> Gemfile
echo "gem 'pg', '~> 1.0'" >> Gemfile
bundle install
cp ../database.yml config

cp ../migration_1.rb db/migrate/20191026153028_migration_1.rb
cp ../migration_2.rb db/migrate/20191026153029_migration_2.rb
bundle exec rake db:drop db:create db:migrate --trace

# Done!
bundle exec rake db:drop
rm -rf target
