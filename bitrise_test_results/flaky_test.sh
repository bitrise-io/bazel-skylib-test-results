#!/usr/bin/env bash
# Fails about half of the attempts; flaky = True gives it three, so it usually ends up flaky.
if (( RANDOM % 2 )); then
  echo "unlucky attempt"
  exit 1
fi
echo "lucky attempt"
