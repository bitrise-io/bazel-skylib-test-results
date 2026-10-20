#!/usr/bin/env bash
# Writes a JUnit XML with several suites and a mix of passing, failing, erroring and skipped cases,
# plus captured output, like a real Java or pytest run. Fails when any case failed.

cases() {
  local suite="$1" count="$2" failing="$3"
  local i name
  for ((i = 1; i <= count; i++)); do
    name="${suite}_case_${i}"
    if [[ "$i" == "$failing" ]]; then
      cat <<CASE
    <testcase classname="${suite}" name="${name}" time="0.0$((i % 9 + 1))">
      <failure message="expected ${i} but was $((i + 1))" type="AssertionError">AssertionError: expected ${i} but was $((i + 1))
        at ${suite}.${name}(${suite}.java:$((i * 7)))
        at org.junit.runners.model.FrameworkMethod\$1.runReflectiveCall(FrameworkMethod.java:59)
        at org.junit.internal.runners.model.ReflectiveCallable.run(ReflectiveCallable.java:12)</failure>
      <system-out>setting up ${name}
fixture loaded: 128 rows</system-out>
    </testcase>
CASE
    else
      echo "    <testcase classname=\"${suite}\" name=\"${name}\" time=\"0.0$((i % 9 + 1))\"/>"
    fi
  done
}

cat > "${XML_OUTPUT_FILE}" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="CalculatorTest" tests="12" failures="1" errors="0" skipped="0">
$(cases CalculatorTest 12 5)
  </testsuite>
  <testsuite name="StringUtilsTest" tests="10" failures="0" errors="1" skipped="1">
$(cases StringUtilsTest 8 0)
    <testcase classname="StringUtilsTest" name="StringUtilsTest_unicode" time="0.003">
      <error message="NullPointerException" type="java.lang.NullPointerException">java.lang.NullPointerException
        at StringUtils.normalize(StringUtils.java:88)
        at StringUtilsTest.StringUtilsTest_unicode(StringUtilsTest.java:41)</error>
    </testcase>
    <testcase classname="StringUtilsTest" name="StringUtilsTest_locale" time="0">
      <skipped message="requires a Turkish locale"/>
    </testcase>
  </testsuite>
  <testsuite name="ParserTest" tests="8" failures="0" errors="0" skipped="0">
$(cases ParserTest 8 0)
    <system-out>parsed 4096 tokens in 12 ms
cache warm: yes</system-out>
  </testsuite>
</testsuites>
XML

echo "wrote 30 JUnit test cases (1 failure, 1 error, 1 skipped)"
exit 1
