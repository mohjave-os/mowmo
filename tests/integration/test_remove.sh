#!/usr/bin/env bash
set -euo pipefail

# Test: mowmo remove outputs valid JSON and package is gone

# Ensure nano is installed first
pacman -S --noconfirm nano > /dev/null 2>&1 || true

# Remove it via mowmo
output=$(mowmo remove nano)

# Validate JSON
echo "$output" | jq empty || { echo "Invalid JSON output"; exit 1; }

# Check required fields
status=$(echo "$output" | jq -r '.status')
command_field=$(echo "$output" | jq -r '.command')
package=$(echo "$output" | jq -r '.package')

[[ "$status" == "success" ]] || { echo "Expected status=success, got $status"; exit 1; }
[[ "$command_field" == "remove" ]] || { echo "Expected command=remove, got $command_field"; exit 1; }
[[ "$package" == "nano" ]] || { echo "Expected package=nano, got $package"; exit 1; }

# Verify nano is gone
if pacman -Q nano > /dev/null 2>&1; then
    echo "nano still installed after remove"
    exit 1
fi

exit 0
