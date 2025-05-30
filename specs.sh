#! /usr/bin/env bash
set -euo pipefail

cd "${0%/*}"
bundle check || bundle install
[ "${CI:-}" = "true" ] && ./bundle_install_each_appraisal.sh
bundle exec appraisal rspec
