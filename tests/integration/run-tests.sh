#!/usr/bin/env bash
set -euo pipefail

# Integration test runner for mowmo
# Executes all test_*.sh scripts and reports pass/fail summary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0
FAILED_TESTS=()

echo "=== mowmo integration tests ==="
echo ""

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    test_name="$(basename "$test_file")"
    echo -n "Running $test_name... "

    if bash "$test_file" 2>/dev/null; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$test_name")
    fi
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    echo "Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "  - $t"
    done
    exit 1
fi

exit 0
