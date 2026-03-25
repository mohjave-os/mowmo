# Data Model: Dockerfile + Arch Base Image to Registry

**Date**: 2026-03-25
**Feature**: 001-dockerfile-base-image

## Overview

mowmo v1 has no persistent data store. The data model describes the JSON schemas exchanged between the mowmo CLI (stdout) and the kernel orchestrator's workers, plus the exit code contract.

## Entity: Command Result

Every mowmo command produces exactly one JSON object on stdout upon completion.

### Common Fields (all commands)

| Field     | Type    | Required   | Description                                                      |
|-----------|---------|------------|------------------------------------------------------------------|
| command   | string  | yes        | The subcommand name: install, remove, search, update, list, info |
| status    | string  | yes        | "success" or "failed"                                            |
| error     | string  | on failure | Human-readable error message (only present when status=failed)   |
| exit_code | integer | on failure | Numeric exit code per constitution Art. III.3                    |

### install Result

| Field   | Type   | Description                      |
|---------|--------|----------------------------------|
| package | string | Package name that was installed  |
| version | string | Installed version string         |
| source  | string | "pacman" or "aur"                |

### remove Result

| Field   | Type   | Description                    |
|---------|--------|--------------------------------|
| package | string | Package name that was removed  |

### search Result

| Field               | Type   | Description                              |
|---------------------|--------|------------------------------------------|
| query               | string | The search query                         |
| results             | array  | Array of match objects                   |
| results[].name      | string | Package name                             |
| results[].version   | string | Available version                        |
| results[].description | string | Package description                    |
| results[].source    | string | "core", "extra", "multilib", or "aur"   |

### update Result

| Field                    | Type    | Description                    |
|--------------------------|---------|--------------------------------|
| updated                  | integer | Number of packages updated     |
| packages                 | array   | Array of updated package objects|
| packages[].name          | string  | Package name                   |
| packages[].old_version   | string  | Previous version               |
| packages[].new_version   | string  | New version                    |

### list Result

| Field             | Type    | Description                      |
|-------------------|---------|----------------------------------|
| count             | integer | Total installed packages         |
| packages          | array   | Array of installed package objects|
| packages[].name   | string  | Package name                     |
| packages[].version| string  | Installed version                |

### info Result

| Field       | Type    | Description                              |
|-------------|---------|------------------------------------------|
| package     | string  | Package name                             |
| version     | string  | Installed or available version           |
| description | string  | Package description                      |
| url         | string  | Upstream URL                             |
| installed   | boolean | Whether the package is currently installed|
| size        | string  | Installed size (human-readable)          |
| depends     | array   | Array of dependency package names        |

## Entity: Exit Codes

Per constitution Art. III.3:

| Code | Meaning                  | When                                    |
|------|--------------------------|-----------------------------------------|
| 0    | Success                  | Command completed as expected           |
| 1    | Package not found        | install/remove/info target doesn't exist|
| 2    | Dependency conflict      | install would break dependencies        |
| 3    | Permission denied        | Not running as root                     |
| 4    | Network error            | Cannot reach repositories               |
| 5    | Disk space insufficient  | Not enough space for install/update     |
| 99   | Unknown error            | Any unhandled pacman/paru error         |

## Entity: Docker Image Tags

| Tag Pattern | Example                                         | Purpose                                          |
|-------------|-------------------------------------------------|--------------------------------------------------|
| :latest     | registry.core.mohjave.com/mowmo:latest          | Always points to most recent build               |
| :YYYY-MM-DD | registry.core.mohjave.com/mowmo:2026-03-25      | Pinnable date-based tag for reproducibility      |

## Relationships

```text
Kernel Orchestrator
    |
    | spawns subprocess
    v
mowmo CLI (mowmo.sh)
    |
    | wraps
    v
pacman / paru
    |
    | produces
    v
Command Result (JSON on stdout) + Exit Code
    |
    | deserialized by
    v
PackageInstallWorker / PackageRemoveWorker / PackageSearchWorker (serde_json::from_str)
```

## Validation Rules

- All string fields must be valid UTF-8
- Package names must match Arch Linux naming conventions: `[a-z0-9@._+-]+`
- Version strings follow Arch versioning: `epoch:pkgver-pkgrel`
- JSON output must be a single valid JSON object (not JSON Lines) per invocation
- Exit code must match one of the defined codes (0, 1, 2, 3, 4, 5, 99)
