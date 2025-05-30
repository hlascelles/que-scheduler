#! /usr/bin/env bash
set -euo pipefail

cd "${0%/*}"
bundle check || bundle install
echo "Running fasterer..."
bundle exec fasterer
echo "Running rubocop..."
bundle exec rubocop
echo "Running reek..."
bundle exec reek
