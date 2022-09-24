#!/usr/bin/env bash
set -euo pipefail

echo "Start a docker container with: docker run -p 5430:5432 postgres:9.6.0 then run this script."
DB_PORT=5430 DB_PASSWORD=postgres bundle exec appraisal rspec "$@"
