#!/usr/bin/env bash

set -euo pipefail

echo "--- :rubygems: Setting up Gems"
install_gems

echo "--- 🧪 Building and Running Tests"
set +e
bundle exec fastlane ios test output_directory:"$TEST_RESULTS_DIR"
TESTS_EXIT_STATUS=$?
set -e

# `report.junit` is `scan`'s default name for the JUnit report it writes into `output_directory`.
annotate_test_failures "$TEST_RESULTS_DIR/report.junit"

exit $TESTS_EXIT_STATUS
