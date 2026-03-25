#!/usr/bin/env bash
set -euo pipefail

# Test: mowmo search outputs valid JSON with non-empty results

output=$(mowmo search vim)

# Validate JSON
echo "$output" | jq empty || { echo "Invalid JSON output"; exit 1; }

# Check required fields
status=$(echo "$output" | jq -r '.status')
command_field=$(echo "$output" | jq -r '.command')
query=$(echo "$output" | jq -r '.query')
results_count=$(echo "$output" | jq '.results | length')

[[ "$status" == "success" ]] || { echo "Expected status=success, got $status"; exit 1; }
[[ "$command_field" == "search" ]] || { echo "Expected command=search, got $command_field"; exit 1; }
[[ "$query" == "vim" ]] || { echo "Expected query=vim, got $query"; exit 1; }
[[ "$results_count" -gt 0 ]] || { echo "Expected non-empty results array"; exit 1; }

# Verify result objects have expected fields
first_name=$(echo "$output" | jq -r '.results[0].name')
[[ -n "$first_name" ]] || { echo "Missing name in first result"; exit 1; }

exit 0
