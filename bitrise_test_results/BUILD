# Tests that exercise every outcome the Bitrise invocation page shows: passed, failed, flaky,
# sharded, and JUnit test cases (passing and failing). The failing and flaky targets are tagged
# "external" so they run on every build instead of being served from the cache.
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

sh_test(
    name = "flaky_test",
    srcs = ["flaky_test.sh"],
    flaky = True,
    tags = ["external"],
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
