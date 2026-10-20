#!/usr/bin/env bash
# Bazel asks sharded tests to touch this file to confirm they support sharding.
touch "${TEST_SHARD_STATUS_FILE}"
echo "running shard $((TEST_SHARD_INDEX + 1)) of ${TEST_TOTAL_SHARDS}"
