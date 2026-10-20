#!/usr/bin/env bash
# Fails the first attempt of every build and passes the retry, so the result is always FLAKY.
# The attempts share a marker file because the test runs unsandboxed (see BUILD).
marker="/tmp/bitrise_flaky_test_${BITRISE_BUILD_SLUG:-$(date +%Y%m%d%H%M)}"
if [[ ! -e "$marker" ]]; then
  touch "$marker"
  echo "unlucky first attempt"
  exit 1
fi
echo "lucky retry"
