# Tests that exercise every outcome the Bitrise invocation page shows: passed, failed, flaky
# (always: it fails once and passes the retry), sharded, and JUnit test cases (passing, failing,
# and a 30-case mixed run with failures, an error and a skipped case). The failing and flaky
# targets are tagged "external" so they run on every build instead of being served from the cache.
load("@rules_shell//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "passing_test",
    srcs = ["passing_test.sh"],
)

sh_test(
    name = "sharded_test",
    srcs = ["sharded_test.sh"],
    shard_count = 4,
)

# Unsandboxed so the attempts of one build share a marker in /tmp; BITRISE_BUILD_SLUG tells the
# builds apart without changing the other tests' cache keys.
sh_test(
    name = "flaky_test",
    srcs = ["flaky_test.sh"],
    env_inherit = ["BITRISE_BUILD_SLUG"],
    flaky = True,
    tags = [
        "external",
        "no-sandbox",
    ],
)

sh_test(
    name = "failing_test",
    srcs = ["failing_test.sh"],
    tags = ["external"],
)

sh_test(
    name = "junit_passing_test",
    srcs = ["junit_test.sh"],
    args = ["pass"],
)

sh_test(
    name = "junit_failing_test",
    srcs = ["junit_test.sh"],
    args = ["fail"],
    tags = ["external"],
)

sh_test(
    name = "junit_mixed_test",
    srcs = ["junit_mixed_test.sh"],
    tags = ["external"],
)
