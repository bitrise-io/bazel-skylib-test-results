"""Macros that generate the heavy test scenarios from heavy_test.sh."""

load("@rules_shell//shell:sh_test.bzl", "sh_test")

# Every heavy target is "manual" so `bazel test //...` (the `test` workflow) skips them; each
# scenario is run through its test_suite.
_BASE_TAGS = ["manual", "heavy"]

def _pad(i, width):
    s = str(i)
    return "0" * (width - len(s)) + s

def _test(name, args, tags = [], **kwargs):
    sh_test(
        name = name,
        srcs = ["heavy_test.sh"],
        args = args,
        tags = _BASE_TAGS + tags,
        **kwargs
    )

def heavy_wide(name, count):
    """`count` small targets with 1-8 cases each, about 1% failing and 0.5% flaky."""
    tests = []
    for i in range(count):
        test = "%s_%s" % (name, _pad(i, 4))
        tags = ["team-%d" % (i % 40), "wide"]
        flaky = i % 200 == 11
        if flaky:
            tags.append("no-sandbox")
        _test(test, ["wide", str(i)], tags = tags, flaky = flaky, size = "small")
        tests.append(test)
    native.test_suite(name = name, tests = tests, tags = ["manual"])

def heavy_deep(name, targets):
    """Targets with very many cases each; `targets` maps a name suffix to its shape."""
    tests = []
    for suffix, shape in targets.items():
        test = "%s_%s" % (name, suffix)
        _test(
            test,
            ["deep"] + [str(shape[k]) for k in ["cases", "fail_every", "out", "fail_out", "stack"]],
            tags = ["deep"],
            shard_count = shape.get("shards", 1),
        )
        tests.append(test)
    native.test_suite(name = name, tests = tests, tags = ["manual"])

# 25 tags, over the 20 kept per target, and two longer than the 64 bytes kept per tag.
_MANY_TAGS = ["owner-team-" + _pad(i, 2) for i in range(23)] + [
    "very-long-tag-" + "x" * 80,
    "another-very-long-tag-" + "y" * 100,
]

def heavy_noisy(name, flaky, failing, passing, shards):
    """Flaky, failing, sharded, timing out, big-log and malformed-XML targets."""
    tests = []

    def add(test, args, tags = [], **kwargs):
        _test(test, args, tags = ["noisy"] + tags, **kwargs)
        tests.append(test)

    for i in range(flaky):
        add("%s_flaky_%s" % (name, _pad(i, 3)), ["noisy-flaky"], tags = _MANY_TAGS + ["no-sandbox"], flaky = True)
    for i in range(failing):
        add("%s_fail_%s" % (name, _pad(i, 3)), ["noisy-fail"], tags = _MANY_TAGS)
    for i in range(passing):
        add("%s_pass_%s" % (name, _pad(i, 3)), ["noisy-pass"])
    for i in range(shards):
        add("%s_shard_%s" % (name, _pad(i, 2)), ["noisy-shard"], shard_count = 20)
    for i in range(2):
        add("%s_timeout_%d" % (name, i), ["noisy-timeout"], timeout = "short")
    for mib in [12, 24, 40]:
        add("%s_biglog_%dmib" % (name, mib), ["noisy-biglog", str(mib)])
    add(name + "_ctrlxml", ["noisy-ctrlxml"])
    add(name + "_unicode", ["noisy-unicode"])
    add(name + "_badxml", ["noisy-badxml"])
    add(name + "_secret", ["noisy-secret"])
    native.test_suite(name = name, tests = tests, tags = ["manual"])
