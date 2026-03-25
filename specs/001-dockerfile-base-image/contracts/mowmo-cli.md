# CLI Contract: mowmo

**Version**: v1 (Bash)
**Invocation**: `mowmo <command> [args] [--human]`
**Output**: JSON to stdout (default), `[mowmo]`-prefixed plain text with `--human` flag
**Errors**: Plain text to stderr, exit code per Art. III.3

## Commands

### mowmo install \<package\>

Installs a package via pacman. Falls back to paru for AUR packages.

```bash
mowmo install firefox
```

**Success output** (exit 0):

```json
{
  "command": "install",
  "package": "firefox",
  "version": "127.0.2-1",
  "source": "extra",
  "status": "success"
}
```

**Failure output** (exit 1):

```json
{
  "command": "install",
  "package": "notreal",
  "status": "failed",
  "error": "target not found: notreal",
  "exit_code": 1
}
```

**Human output** (`--human`, exit 0):

```text
[mowmo] install firefox
[mowmo] resolving dependencies...
[mowmo] installing firefox (127.0.2-1)...
[mowmo] done: firefox installed successfully
```

### mowmo remove \<package\>

Removes an installed package via pacman.

```bash
mowmo remove firefox
```

**Success output** (exit 0):

```json
{
  "command": "remove",
  "package": "firefox",
  "status": "success"
}
```

**Failure output** (exit 1):

```json
{
  "command": "remove",
  "package": "notinstalled",
  "status": "failed",
  "error": "target not found: notinstalled",
  "exit_code": 1
}
```

### mowmo search \<query\>

Searches package repositories via pacman -Ss. Returns structured results.

```bash
mowmo search editor
```

**Success output** (exit 0):

```json
{
  "command": "search",
  "query": "editor",
  "status": "success",
  "results": [
    {
      "name": "vim",
      "version": "9.1.0-1",
      "description": "Vi Improved, a highly configurable text editor",
      "source": "extra"
    },
    {
      "name": "nano",
      "version": "7.2-1",
      "description": "Pico editor clone with enhancements",
      "source": "core"
    }
  ]
}
```

### mowmo update

Performs a full system update via pacman -Syu.

```bash
mowmo update
```

**Success output** (exit 0):

```json
{
  "command": "update",
  "status": "success",
  "updated": 3,
  "packages": [
    {"name": "linux", "old_version": "6.8.1-1", "new_version": "6.8.2-1"},
    {"name": "mesa", "old_version": "24.0.2-1", "new_version": "24.0.3-1"},
    {"name": "vim", "old_version": "9.1.0-1", "new_version": "9.1.1-1"}
  ]
}
```

### mowmo list

Lists all installed packages.

```bash
mowmo list
```

**Success output** (exit 0):

```json
{
  "command": "list",
  "status": "success",
  "count": 342,
  "packages": [
    {"name": "base", "version": "3-2"},
    {"name": "firefox", "version": "127.0.2-1"}
  ]
}
```

### mowmo info \<package\>

Shows detailed information about a package.

```bash
mowmo info firefox
```

**Success output** (exit 0):

```json
{
  "command": "info",
  "package": "firefox",
  "status": "success",
  "version": "127.0.2-1",
  "description": "Standalone web browser from mozilla.org",
  "url": "https://www.mozilla.org/firefox/",
  "installed": true,
  "size": "234.5 MiB",
  "depends": ["dbus-glib", "gtk3", "libxt", "nss"]
}
```

## Exit Codes

| Code | Meaning                          |
|------|----------------------------------|
| 0    | Success                          |
| 1    | Package not found                |
| 2    | Dependency conflict              |
| 3    | Permission denied (not root)     |
| 4    | Network error                    |
| 5    | Disk space insufficient          |
| 99   | Unknown error                    |

## Global Flags

| Flag      | Effect                                                       |
|-----------|--------------------------------------------------------------|
| `--human` | Output `[mowmo]`-prefixed plain text instead of JSON         |

## Invariants

- Exactly one JSON object per invocation on stdout (no JSON Lines, no partial output)
- Exit code always set, even if JSON output fails
- stderr may contain `[mowmo]` debug lines regardless of output mode
- JSON is constructed with jq for type safety; all string values properly escaped
- Package names passed through as-is to pacman/paru (no sanitization — pacman handles validation)
