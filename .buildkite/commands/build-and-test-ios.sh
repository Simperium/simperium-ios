#!/usr/bin/env bash

set -euo pipefail

echo "--- :rubygems: Setting up Gems"
install_gems

echo "--- :test_tube: Building and Running Tests"
set +e
bundle exec fastlane ios test
TESTS_EXIT_STATUS=$?
set -e

annotate_test_failures .build/test-results/report.junit

exit $TESTS_EXIT_STATUS
