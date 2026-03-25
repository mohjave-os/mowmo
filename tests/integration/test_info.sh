#!/usr/bin/env bash
set -euo pipefail

# Test: mowmo info outputs valid JSON with expected fields

output=$(mowmo info vim)

# Validate JSON
echo "$output" | jq empty || { echo "Invalid JSON output"; exit 1; }

# Check required fields
status=$(echo "$output" | jq -r '.status')
command_field=$(echo "$output" | jq -r '.command')
package=$(echo "$output" | jq -r '.package')
version=$(echo "$output" | jq -r '.version')
description=$(echo "$output" | jq -r '.description')
installed=$(echo "$output" | jq '.installed')

[[ "$status" == "success" ]] || { echo "Expected status=success, got $status"; exit 1; }
[[ "$command_field" == "info" ]] || { echo "Expected command=info, got $command_field"; exit 1; }
[[ "$package" == "vim" ]] || { echo "Expected package=vim, got $package"; exit 1; }
[[ -n "$version" ]] || { echo "Missing version"; exit 1; }
[[ -n "$description" ]] || { echo "Missing description"; exit 1; }
[[ "$installed" == "true" || "$installed" == "false" ]] || { echo "Expected boolean installed, got $installed"; exit 1; }

# Verify depends is an array
has_depends=$(echo "$output" | jq 'has("depends")')
[[ "$has_depends" == "true" ]] || { echo "Missing depends field"; exit 1; }

exit 0
