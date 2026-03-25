#!/usr/bin/env bash
set -euo pipefail

# Test: mowmo update outputs valid JSON with status=success

output=$(mowmo update)

# Validate JSON
echo "$output" | jq empty || { echo "Invalid JSON output"; exit 1; }

# Check required fields
status=$(echo "$output" | jq -r '.status')
command_field=$(echo "$output" | jq -r '.command')
updated=$(echo "$output" | jq '.updated')

[[ "$status" == "success" ]] || { echo "Expected status=success, got $status"; exit 1; }
[[ "$command_field" == "update" ]] || { echo "Expected command=update, got $command_field"; exit 1; }
[[ "$updated" =~ ^[0-9]+$ ]] || { echo "Expected numeric updated count, got $updated"; exit 1; }

# Verify packages array exists
has_packages=$(echo "$output" | jq 'has("packages")')
[[ "$has_packages" == "true" ]] || { echo "Missing packages array"; exit 1; }

exit 0
