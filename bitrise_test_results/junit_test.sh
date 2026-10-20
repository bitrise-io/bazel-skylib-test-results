#!/usr/bin/env bash
# Writes its own JUnit XML so the invocation has test cases, like a JUnit or pytest runner would.
mode="$1"
failure=""
if [[ "$mode" == "fail" ]]; then
  failure='<failure message="expected 1, got 0" type="AssertionError">AssertionError: expected 1, got 0
    at Calculator.divide(calculator_test.sh:12)</failure>'
fi

cat > "${XML_OUTPUT_FILE}" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="CalculatorTest" tests="3" failures="$([[ -n "$failure" ]] && echo 1 || echo 0)">
    <testcase classname="CalculatorTest" name="adds" time="0.012"/>
    <testcase classname="CalculatorTest" name="subtracts" time="0.008"/>
    <testcase classname="CalculatorTest" name="divides" time="0.021">${failure}</testcase>
  </testsuite>
</testsuites>
XML

echo "ran 3 test cases (${mode})"
[[ "$mode" == "pass" ]]
