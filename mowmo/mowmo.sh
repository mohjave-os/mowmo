#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2250
set -euo pipefail

# mowmo v1 - Mohjave OS package manager CLI
# Wraps pacman/paru with structured JSON output (default) or [mowmo]-prefixed plain text (--human)

# Exit codes per constitution Art. III.3
readonly EXIT_SUCCESS=0
readonly EXIT_NOT_FOUND=1
readonly EXIT_CONFLICT=2
readonly EXIT_PERMISSION=3
readonly EXIT_NETWORK=4
readonly EXIT_DISK=5
readonly EXIT_UNKNOWN=99

# Global state
HUMAN_MODE=false

# --- Output helpers ---

json_output() {
    # Pass arbitrary jq arguments to construct JSON
    jq -n "$@"
}

json_error() {
    local command="$1"
    local package="${2:-}"
    local error_msg="$3"
    local exit_code="$4"

    if [[ -n "$package" ]]; then
        jq -n \
            --arg command "$command" \
            --arg package "$package" \
            --arg error "$error_msg" \
            --argjson exit_code "$exit_code" \
            '{command: $command, package: $package, status: "failed", error: $error, exit_code: $exit_code}'
    else
        jq -n \
            --arg command "$command" \
            --arg error "$error_msg" \
            --argjson exit_code "$exit_code" \
            '{command: $command, status: "failed", error: $error, exit_code: $exit_code}'
    fi
}

human_msg() {
    echo "[mowmo] $*" >&2
}

# Map pacman exit codes to mowmo exit codes
map_exit_code() {
    local pacman_output="$1"
    local pacman_exit="$2"

    if [[ "$pacman_exit" -eq 0 ]]; then
        echo "$EXIT_SUCCESS"
        return
    fi

    if echo "$pacman_output" | grep -qi "target not found"; then
        echo "$EXIT_NOT_FOUND"
    elif echo "$pacman_output" | grep -qi "conflicting"; then
        echo "$EXIT_CONFLICT"
    elif echo "$pacman_output" | grep -qi "permission denied\|requires root"; then
        echo "$EXIT_PERMISSION"
    elif echo "$pacman_output" | grep -qi "could not resolve\|download\|connection"; then
        echo "$EXIT_NETWORK"
    elif echo "$pacman_output" | grep -qi "not enough free disk\|no space"; then
        echo "$EXIT_DISK"
    else
        echo "$EXIT_UNKNOWN"
    fi
}

# --- Commands ---

cmd_install() {
    local package="${1:-}"
    if [[ -z "$package" ]]; then
        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: no package specified"
            exit "$EXIT_NOT_FOUND"
        fi
        json_error "install" "" "no package specified" "$EXIT_NOT_FOUND"
        exit "$EXIT_NOT_FOUND"
    fi

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "install $package"
        human_msg "resolving dependencies..."
    fi

    local output
    local rc=0
    local source="pacman"

    # Try pacman first
    output=$(pacman -S --noconfirm "$package" 2>&1) || rc=$?

    # If pacman fails with not-found, try paru for AUR
    if [[ "$rc" -ne 0 ]] && echo "$output" | grep -qi "target not found"; then
        rc=0
        source="aur"
        output=$(sudo -u builduser paru -S --noconfirm "$package" 2>&1) || rc=$?
    fi

    if [[ "$rc" -ne 0 ]]; then
        local exit_code
        exit_code=$(map_exit_code "$output" "$rc")
        local error_msg
        error_msg=$(echo "$output" | grep -i "error\|target not found" | head -1 | sed 's/^.*error: //')
        if [[ -z "$error_msg" ]]; then
            error_msg="package operation failed"
        fi

        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: $error_msg"
            exit "$exit_code"
        fi
        json_error "install" "$package" "$error_msg" "$exit_code"
        exit "$exit_code"
    fi

    # Get installed version
    local version
    version=$(pacman -Q "$package" 2>/dev/null | awk '{print $2}') || version="unknown"

    # Determine source repository
    if [[ "$source" != "aur" ]]; then
        source=$(pacman -Si "$package" 2>/dev/null | grep "^Repository" | awk '{print $3}') || source="unknown"
    fi

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "installing $package ($version)..."
        human_msg "done: $package installed successfully"
        exit "$EXIT_SUCCESS"
    fi

    json_output \
        --arg package "$package" \
        --arg version "$version" \
        --arg source "$source" \
        '{command: "install", package: $package, version: $version, source: $source, status: "success"}'
    exit "$EXIT_SUCCESS"
}

cmd_remove() {
    local package="${1:-}"
    if [[ -z "$package" ]]; then
        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: no package specified"
            exit "$EXIT_NOT_FOUND"
        fi
        json_error "remove" "" "no package specified" "$EXIT_NOT_FOUND"
        exit "$EXIT_NOT_FOUND"
    fi

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "remove $package"
    fi

    local output
    local rc=0
    output=$(pacman -R --noconfirm "$package" 2>&1) || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        local exit_code
        exit_code=$(map_exit_code "$output" "$rc")
        local error_msg
        error_msg=$(echo "$output" | grep -i "error\|target not found" | head -1 | sed 's/^.*error: //')
        if [[ -z "$error_msg" ]]; then
            error_msg="package removal failed"
        fi

        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: $error_msg"
            exit "$exit_code"
        fi
        json_error "remove" "$package" "$error_msg" "$exit_code"
        exit "$exit_code"
    fi

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "done: $package removed successfully"
        exit "$EXIT_SUCCESS"
    fi

    json_output \
        --arg package "$package" \
        '{command: "remove", package: $package, status: "success"}'
    exit "$EXIT_SUCCESS"
}

cmd_search() {
    local query="${1:-}"
    if [[ -z "$query" ]]; then
        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: no search query specified"
            exit "$EXIT_NOT_FOUND"
        fi
        json_error "search" "" "no search query specified" "$EXIT_NOT_FOUND"
        exit "$EXIT_NOT_FOUND"
    fi

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "search $query"
    fi

    local output
    local rc=0
    output=$(pacman -Ss "$query" 2>&1) || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        # pacman -Ss returns 1 when no results found — not an error
        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "no results found for: $query"
            exit "$EXIT_SUCCESS"
        fi
        json_output \
            --arg query "$query" \
            '{command: "search", query: $query, status: "success", results: []}'
        exit "$EXIT_SUCCESS"
    fi

    # Parse pacman -Ss output: pairs of lines
    # Line 1: repo/name version (optional: [installed])
    # Line 2:     description
    local results_json
    results_json=$(echo "$output" | awk '
        /^[a-z]/ {
            # Repository/name line
            split($1, reponame, "/")
            repo = reponame[1]
            name = reponame[2]
            version = $2
            getline
            # Description line (trim leading whitespace)
            gsub(/^[ \t]+/, "")
            desc = $0
            printf "%s\t%s\t%s\t%s\n", name, version, desc, repo
        }
    ' | jq -R -s '
        split("\n") | map(select(length > 0)) | map(
            split("\t") |
            {name: .[0], version: .[1], description: .[2], source: .[3]}
        )
    ')

    if [[ "$HUMAN_MODE" == true ]]; then
        echo "$output" | while IFS= read -r line; do
            human_msg "$line"
        done
        exit "$EXIT_SUCCESS"
    fi

    jq -n \
        --arg query "$query" \
        --argjson results "$results_json" \
        '{command: "search", query: $query, status: "success", results: $results}'
    exit "$EXIT_SUCCESS"
}

cmd_update() {
    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "update"
        human_msg "checking for updates..."
    fi

    # Capture package list before update
    local before
    before=$(pacman -Q 2>/dev/null)

    local output
    local rc=0
    output=$(pacman -Syu --noconfirm 2>&1) || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        local exit_code
        exit_code=$(map_exit_code "$output" "$rc")
        local error_msg
        error_msg=$(echo "$output" | grep -i "error" | head -1 | sed 's/^.*error: //')
        if [[ -z "$error_msg" ]]; then
            error_msg="system update failed"
        fi

        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: $error_msg"
            exit "$exit_code"
        fi
        json_error "update" "" "$error_msg" "$exit_code"
        exit "$exit_code"
    fi

    # Capture package list after update and diff
    local after
    after=$(pacman -Q 2>/dev/null)

    local packages_json
    packages_json=$(diff <(echo "$before") <(echo "$after") 2>/dev/null | \
        grep "^[<>]" | \
        awk '
            /^< / { old[$2] = $3 }
            /^> / { new[$2] = $3 }
            END {
                for (pkg in new) {
                    if (pkg in old && old[pkg] != new[pkg]) {
                        printf "%s\t%s\t%s\n", pkg, old[pkg], new[pkg]
                    }
                }
            }
        ' | jq -R -s '
            split("\n") | map(select(length > 0)) | map(
                split("\t") |
                {name: .[0], old_version: .[1], new_version: .[2]}
            )
        ') || packages_json="[]"

    local updated_count
    updated_count=$(echo "$packages_json" | jq 'length')

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "done: $updated_count packages updated"
        exit "$EXIT_SUCCESS"
    fi

    jq -n \
        --argjson updated "$updated_count" \
        --argjson packages "$packages_json" \
        '{command: "update", status: "success", updated: $updated, packages: $packages}'
    exit "$EXIT_SUCCESS"
}

cmd_list() {
    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "list"
    fi

    local output
    output=$(pacman -Q 2>/dev/null)

    local packages_json
    packages_json=$(echo "$output" | jq -R -s '
        split("\n") | map(select(length > 0)) | map(
            split(" ") |
            {name: .[0], version: .[1]}
        )
    ')

    local count
    count=$(echo "$packages_json" | jq 'length')

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "$count packages installed"
        echo "$output" | while IFS= read -r line; do
            human_msg "$line"
        done
        exit "$EXIT_SUCCESS"
    fi

    jq -n \
        --argjson count "$count" \
        --argjson packages "$packages_json" \
        '{command: "list", status: "success", count: $count, packages: $packages}'
    exit "$EXIT_SUCCESS"
}

cmd_info() {
    local package="${1:-}"
    if [[ -z "$package" ]]; then
        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: no package specified"
            exit "$EXIT_NOT_FOUND"
        fi
        json_error "info" "" "no package specified" "$EXIT_NOT_FOUND"
        exit "$EXIT_NOT_FOUND"
    fi

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "info $package"
    fi

    local output
    local rc=0
    local installed=true

    # Try installed package first (pacman -Qi), then available (pacman -Si)
    output=$(pacman -Qi "$package" 2>&1) || {
        rc=$?
        installed=false
        output=$(pacman -Si "$package" 2>&1) || rc=$?
    }

    if [[ "$rc" -ne 0 ]]; then
        local exit_code
        exit_code=$(map_exit_code "$output" "$rc")
        local error_msg
        error_msg=$(echo "$output" | grep -i "error\|was not found" | head -1 | sed 's/^.*error: //')
        if [[ -z "$error_msg" ]]; then
            error_msg="package not found: $package"
        fi

        if [[ "$HUMAN_MODE" == true ]]; then
            human_msg "error: $error_msg"
            exit "$exit_code"
        fi
        json_error "info" "$package" "$error_msg" "$exit_code"
        exit "$exit_code"
    fi

    # Parse pacman output
    local version description url size
    version=$(echo "$output" | grep "^Version" | head -1 | sed 's/^[^:]*: *//')
    description=$(echo "$output" | grep "^Description" | head -1 | sed 's/^[^:]*: *//')
    url=$(echo "$output" | grep "^URL" | head -1 | sed 's/^[^:]*: *//')
    size=$(echo "$output" | grep -i "^Installed Size\|^Download Size" | head -1 | sed 's/^[^:]*: *//')

    # Parse depends
    local depends_line
    depends_line=$(echo "$output" | grep "^Depends On" | head -1 | sed 's/^[^:]*: *//')
    local depends_json
    if [[ "$depends_line" == "None" ]] || [[ -z "$depends_line" ]]; then
        depends_json="[]"
    else
        depends_json=$(echo "$depends_line" | tr ' ' '\n' | sed 's/[>=<].*$//' | jq -R -s 'split("\n") | map(select(length > 0))')
    fi

    if [[ "$HUMAN_MODE" == true ]]; then
        human_msg "Name: $package"
        human_msg "Version: $version"
        human_msg "Description: $description"
        human_msg "URL: $url"
        human_msg "Installed: $installed"
        human_msg "Size: $size"
        human_msg "Depends: $depends_line"
        exit "$EXIT_SUCCESS"
    fi

    jq -n \
        --arg package "$package" \
        --arg version "$version" \
        --arg description "$description" \
        --arg url "$url" \
        --argjson installed "$installed" \
        --arg size "$size" \
        --argjson depends "$depends_json" \
        '{command: "info", package: $package, status: "success", version: $version, description: $description, url: $url, installed: $installed, size: $size, depends: $depends}'
    exit "$EXIT_SUCCESS"
}

# --- Main ---

usage() {
    cat <<'USAGE'
mowmo v1 — Mohjave OS package manager

Usage: mowmo <command> [args] [--human]

Commands:
  install <package>   Install a package (pacman, falls back to AUR)
  remove <package>    Remove an installed package
  search <query>      Search package repositories
  update              Full system update
  list                List all installed packages
  info <package>      Show detailed package information

Flags:
  --human             Output plain text instead of JSON

Exit Codes:
  0   Success
  1   Package not found
  2   Dependency conflict
  3   Permission denied
  4   Network error
  5   Disk space insufficient
  99  Unknown error
USAGE
}

main() {
    # Parse global flags
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "--human" ]]; then
            HUMAN_MODE=true
        else
            args+=("$arg")
        fi
    done

    if [[ "${#args[@]}" -eq 0 ]]; then
        usage
        exit "$EXIT_SUCCESS"
    fi

    local command="${args[0]}"
    local rest=("${args[@]:1}")

    case "$command" in
        install) cmd_install "${rest[0]:-}" ;;
        remove)  cmd_remove "${rest[0]:-}" ;;
        search)  cmd_search "${rest[0]:-}" ;;
        update)  cmd_update ;;
        list)    cmd_list ;;
        info)    cmd_info "${rest[0]:-}" ;;
        --help|-h|help) usage ;;
        *)
            if [[ "$HUMAN_MODE" == true ]]; then
                human_msg "error: unknown command: $command"
                exit "$EXIT_UNKNOWN"
            fi
            json_error "$command" "" "unknown command: $command" "$EXIT_UNKNOWN"
            exit "$EXIT_UNKNOWN"
            ;;
    esac
}

main "$@"
