#! /usr/bin/env bash
set -euo pipefail

# Github actions does a lot to improve caching of dependencies, and sometimes it prevents appraisal
# from bundle installing. Or rather, it thinks the bundle install has already happened, so it
# doesn't download new gems that are needed for different lock files. Here we spin through the lock
# files manually to bundle install them all.

cd gemfiles
DIRECTORY=.

for i in "$DIRECTORY"/*.gemfile; do
  echo "Bundle installing $i"
  BUNDLE_GEMFILE=$i bundle install
done
