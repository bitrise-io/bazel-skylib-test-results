#!/usr/bin/env bash
# One script behind every heavy target: `heavy_test.sh <kind> [args]`. It writes the JUnit XML,
# test.log output and warnings that a large monorepo's test runners would, with sizes taken from
# the arguments so the BUILD file decides the shape.
set -uo pipefail

kind="$1"
shift

xml="${XML_OUTPUT_FILE:-/dev/null}"
warnings="${TEST_WARNINGS_OUTPUT_FILE:-/dev/null}"
target="${TEST_TARGET:-local}"
run_key="${HEAVY_RUN_KEY:-local}"

if [[ -n "${TEST_SHARD_STATUS_FILE:-}" ]]; then
  touch "${TEST_SHARD_STATUS_FILE}"
fi
shard="${TEST_SHARD_INDEX:-0}"
shards="${TEST_TOTAL_SHARDS:-1}"

# Fails the first attempt of each run and passes the retry. Needs the "no-sandbox" tag so the
# attempts share /tmp; mkdir is atomic, so parallel runs of one target don't race.
first_attempt() {
  local marker="/tmp/heavy_flaky_${run_key}_${target//[^A-Za-z0-9]/_}_${TEST_RUN_NUMBER:-0}_${shard}"
  mkdir "$marker" 2>/dev/null
}

# Writes <count> cases. Every <fail_every>th fails with a <stack>-line trace and <fail_out> bytes
# of stdout and stderr; some others error or are skipped; passing cases get <out> bytes of stdout.
write_cases() {
  local suite="$1" count="$2" fail_every="$3" out="$4" fail_out="$5" stack="$6"
  awk -v suite="$suite" -v count="$count" -v fail_every="$fail_every" -v out="$out" \
    -v fail_out="$fail_out" -v stack="$stack" -v shard="$shard" '
    function filler(n,   s) {
      s = ""
      while (length(s) < n) s = s "log line " length(s) " of " suite " shard " shard " lorem ipsum dolor sit amet\n"
      return substr(s, 1, n)
    }
    BEGIN {
      fo = filler(fail_out); po = filler(out)
      printf "  <testsuite name=\"%s\" tests=\"%d\">\n", suite, count
      for (i = 1; i <= count; i++) {
        name = sprintf("test_%s_s%d_%06d", suite, shard, i)
        printf "    <testcase classname=\"com.example.%s\" name=\"%s\" time=\"0.%03d\">", suite, name, i % 1000
        if (fail_every > 0 && i % fail_every == 0) {
          printf "<failure message=\"expected %d but was %d\" type=\"java.lang.AssertionError\">java.lang.AssertionError: expected %d but was %d\n", i, i + 1, i, i + 1
          for (f = 1; f <= stack; f++) printf "\tat com.example.%s.frame%d(%s.java:%d)\n", suite, f, suite, f * 13
          printf "</failure><system-out>%s</system-out><system-err>%s</system-err>", fo, fo
        } else if (i % 97 == 0) {
          printf "<error message=\"NullPointerException\" type=\"java.lang.NullPointerException\">java.lang.NullPointerException\n\tat com.example.%s.setUp(%s.java:12)</error>", suite, suite
        } else if (i % 53 == 0) {
          printf "<skipped message=\"disabled on CI\"/>"
        } else if (out > 0) {
          printf "<system-out>%s</system-out>", po
        }
        print "</testcase>"
      }
      print "  </testsuite>"
    }'
}

# Fake credentials derived from the run key at runtime, so nothing secret-shaped is committed.
fake_secrets() {
  local hex
  local sum=sha256sum
  command -v sha256sum >/dev/null || sum="shasum -a 256"
  hex="$(printf '%s' "fake-${run_key}" | $sum | cut -c1-64)"
  echo "FAKE github token: gh""p_${hex:0:36}"
  echo "FAKE aws key: AK""IA$(printf '%s' "${hex:36:16}" | tr 'a-f' 'A-F')"
  echo "FAKE password=Hv${hex:10:20}Q"
}

case "$kind" in
  wide)
    # Many small targets: 1-8 cases each; about 1% fail and 0.5% are flaky.
    index="$1"
    cases=$((1 + index % 8))
    fail_every=0
    status=0
    if ((index % 100 == 37)); then
      fail_every=$cases
      status=1
    elif ((index % 200 == 11)) && first_attempt; then
      fail_every=$cases
      status=1
    fi
    echo "running ${cases} cases of target ${index}"
    { echo '<?xml version="1.0" encoding="UTF-8"?>'; echo "<testsuites>"
      write_cases "Wide${index}" "$cases" "$fail_every" 64 512 8
      echo "</testsuites>"; } >"$xml"
    exit "$status"
    ;;

  deep)
    # A few targets with very many cases: deep <cases> <fail_every> <out> <fail_out> <stack>.
    count="$1"
    if ((shards > 1)); then
      count=$((count / shards))
    fi
    { echo '<?xml version="1.0" encoding="UTF-8"?>'; echo "<testsuites>"
      write_cases "Deep" "$count" "$2" "$3" "$4" "$5"
      echo "</testsuites>"; } >"$xml"
    echo "wrote ${count} cases ($(wc -c <"$xml") bytes of XML)"
    (($2 == 0))
    exit
    ;;

  noisy-*)
    # Every noisy target leaves warnings: one line over the 16 KiB field cut and 20 short ones.
    { head -c 20000 /dev/zero | tr '\0' 'w'; echo
      for ((i = 1; i <= 20; i++)); do echo "warning ${i}: deprecated API used in ${target}, see the migration guide"; done
    } >>"$warnings"
    ;;
esac

case "$kind" in
  noisy-pass)
    head -c 262144 /dev/zero | tr '\0' 'p' | fold -w 120
    { echo '<?xml version="1.0" encoding="UTF-8"?><testsuites>'; write_cases Pass 20 0 256 0 0; echo "</testsuites>"; } >"$xml"
    ;;
  noisy-flaky)
    { echo '<?xml version="1.0" encoding="UTF-8"?><testsuites>'; write_cases Flaky 10 0 128 0 0; echo "</testsuites>"; } >"$xml"
    if first_attempt; then
      echo "first attempt fails: connection reset by peer" >&2
      exit 1
    fi
    ;;
  noisy-fail)
    head -c 204800 /dev/zero | tr '\0' 'e' | fold -w 160 >&2
    { echo '<?xml version="1.0" encoding="UTF-8"?><testsuites>'; write_cases Fail 30 10 128 2048 40; echo "</testsuites>"; } >"$xml"
    exit 1
    ;;
  noisy-shard)
    { echo '<?xml version="1.0" encoding="UTF-8"?><testsuites>'; write_cases Shard 50 0 64 0 0; echo "</testsuites>"; } >"$xml"
    echo "shard $((shard + 1)) of ${shards}"
    ((shard != 7))
    exit
    ;;
  noisy-timeout)
    echo "waiting for a server that never answers"
    sleep 600
    ;;
  noisy-biglog)
    # <MiB> of numbered lines, around the worker's 16 MiB per-file copy limit.
    awk -v mib="$1" 'BEGIN { limit = mib * 1048576; n = 0
      while (n < limit) { line = sprintf("%09d INFO big log line of the noisy scenario, padding padding padding", n); print line; n += length(line) + 1 } }'
    ;;
  noisy-ctrlxml)
    # Control characters, an ANSI escape and invalid UTF-8 inside otherwise well-formed XML.
    printf 'colored \033[31mred\033[0m output, bell \a, bytes \xff\xfe\n'
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites><testsuite name="Ctrl" tests="2">' >"$xml"
    printf '<testcase classname="Ctrl" name="ctrl_\001chars"><failure message="bad \033[31mbyte\033[0m \xff">trace \x01\x02\x1f &#1; \xc3\x28 end</failure><system-out>out \xfe\xff \033[0m</system-out></testcase>' >>"$xml"
    printf '<testcase classname="Ctrl" name="ok"/></testsuite></testsuites>\n' >>"$xml"
    exit 1
    ;;
  noisy-unicode)
    # Valid XML that is still awkward: escaped markup, CDATA, emoji, right-to-left and combining text.
    cat >"$xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites><testsuite name="Unicode" tests="2">
<testcase classname="Unicode" name="emoji_🚀_and_ñ"><failure message="&lt;b&gt;expected&lt;/b&gt; &quot;é&quot; &amp; got &#x1F4A5;"><![CDATA[<html> stays text ]]> שלום עולם e&#x301;</failure></testcase>
<testcase classname="Unicode" name="漢字_テスト"><system-out><![CDATA[line with ]]]]><![CDATA[> split CDATA]]></system-out></testcase>
</testsuite></testsuites>
XML
    exit 1
    ;;
  noisy-badxml)
    printf '<?xml version="1.0"?>\n<testsuites><testsuite name="Bad"><testcase name="a" classname="Bad">&bogus;<failure>unterminated' >"$xml"
    exit 1
    ;;
  noisy-secret)
    fake_secrets
    fake_secrets >>"$warnings"
    {
      echo '<?xml version="1.0" encoding="UTF-8"?><testsuites><testsuite name="Secret" tests="1">'
      echo "<testcase classname=\"Secret\" name=\"leaks\"><failure message=\"$(fake_secrets | head -1)\">$(fake_secrets)</failure><system-out>$(fake_secrets)</system-out></testcase>"
      echo '</testsuite></testsuites>'
    } >"$xml"
    exit 1
    ;;
esac
