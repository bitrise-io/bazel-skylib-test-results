#!/usr/bin/env bash
# Runs one heavy scenario on Bitrise: `run.sh <test_suite> [bazel flags]`. Every test action is
# keyed by the build slug, so the tests run on each build instead of coming from the cache. Exit 3
# (some tests failed) is expected and keeps the build green.
set -x

suite="$1"
shift

bazel test "//bitrise_test_results/heavy:${suite}" \
  --keep_going \
  --test_env=HEAVY_RUN_KEY="${BITRISE_BUILD_SLUG:-local-$(date +%s)}" \
  --test_summary=terse \
  --test_output=errors \
  "$@"
code=$?
if [[ $code -eq 3 ]]; then
  echo "Some tests failed, as expected for the ${suite} scenario"
  exit 0
fi
exit $code
