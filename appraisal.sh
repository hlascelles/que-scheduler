#!/usr/bin/env bash
set -euo pipefail

echo "Use a custom port to avoid colliding with a real pg install. Start a docker container with:"
echo "docker run -p 5430:5432 postgres:9.5.0"
echo "then run this script with DB_PORT=5430."

bundle check >& /dev/null || bundle install
bundle exec appraisal install

echo "Checking postgres $DB_HOST is up..."
postgres_up() { pg_isready -h "$DB_HOST" -p 5432; }
until postgres_up; do
    echo "Waiting for postgres to be up"
    sleep 1;
done

DB_PASSWORD=postgres bundle exec appraisal rake spec
