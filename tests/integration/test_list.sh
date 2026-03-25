#!/usr/bin/env bash
set -euo pipefail

# Test: mowmo list outputs valid JSON with count > 0

output=$(mowmo list)

# Validate JSON
echo "$output" | jq empty || { echo "Invalid JSON output"; exit 1; }

# Check required fields
status=$(echo "$output" | jq -r '.status')
command_field=$(echo "$output" | jq -r '.command')
count=$(echo "$output" | jq '.count')
packages_count=$(echo "$output" | jq '.packages | length')

[[ "$status" == "success" ]] || { echo "Expected status=success, got $status"; exit 1; }
[[ "$command_field" == "list" ]] || { echo "Expected command=list, got $command_field"; exit 1; }
[[ "$count" -gt 0 ]] || { echo "Expected count > 0, got $count"; exit 1; }
[[ "$packages_count" -gt 0 ]] || { echo "Expected non-empty packages array"; exit 1; }

# Verify count matches array length
[[ "$count" -eq "$packages_count" ]] || { echo "Count ($count) != packages length ($packages_count)"; exit 1; }

exit 0
