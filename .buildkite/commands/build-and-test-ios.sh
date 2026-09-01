#!/usr/bin/env bash

set -euo pipefail

TEST_RESULTS_DIR="${1:?test results directory}"
JUNIT_REPORT='report.junit'

echo "--- :rubygems: Setting up Gems"
install_gems

echo "--- 🧪 Building and Running Tests"
set +e
bundle exec fastlane ios test output_directory:"$TEST_RESULTS_DIR" output_files:"$JUNIT_REPORT"
TESTS_EXIT_STATUS=$?
set -e

annotate_test_failures "$TEST_RESULTS_DIR/$JUNIT_REPORT"

exit $TESTS_EXIT_STATUS
