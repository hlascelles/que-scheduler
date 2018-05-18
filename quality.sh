#! /usr/bin/env bash
set -euo pipefail

cd $(dirname $0)
bundle exec fasterer
bundle exec rubocop
bundle exec reek
