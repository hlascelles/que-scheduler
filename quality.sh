#! /usr/bin/env bash
set -euo pipefail

cd $(dirname $0)
echo "Running fasterer..."
bundle exec fasterer
echo "Running rubocop..."
bundle exec rubocop
echo "Running reek..."
bundle exec reek
