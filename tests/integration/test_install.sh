#!/usr/bin/env bash
set -euo pipefail

# Test: mowmo install outputs valid JSON with status=success

# Install vim (should be available in base repos)
output=$(mowmo install vim)

# Validate JSON
echo "$output" | jq empty || { echo "Invalid JSON output"; exit 1; }

# Check required fields
status=$(echo "$output" | jq -r '.status')
command_field=$(echo "$output" | jq -r '.command')
package=$(echo "$output" | jq -r '.package')

[[ "$status" == "success" ]] || { echo "Expected status=success, got $status"; exit 1; }
[[ "$command_field" == "install" ]] || { echo "Expected command=install, got $command_field"; exit 1; }
[[ "$package" == "vim" ]] || { echo "Expected package=vim, got $package"; exit 1; }

# Verify vim is actually installed
pacman -Q vim > /dev/null 2>&1 || { echo "vim not actually installed"; exit 1; }

exit 0
