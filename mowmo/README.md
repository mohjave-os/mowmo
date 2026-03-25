# mowmo CLI

mowmo v1 is a Bash CLI that wraps `pacman` and `paru` for Mohjave OS package management.

## Output

By default, all commands output a single JSON object to stdout. Use `--human` for `[mowmo]`-prefixed plain text.

## Commands

### install

```bash
mowmo install <package>
```

Installs via pacman. Falls back to paru for AUR packages.

```json
{"command": "install", "package": "firefox", "version": "127.0.2-1", "source": "extra", "status": "success"}
```

### remove

```bash
mowmo remove <package>
```

```json
{"command": "remove", "package": "firefox", "status": "success"}
```

### search

```bash
mowmo search <query>
```

```json
{"command": "search", "query": "editor", "status": "success", "results": [{"name": "vim", "version": "9.1.0-1", "description": "...", "source": "extra"}]}
```

### update

```bash
mowmo update
```

```json
{"command": "update", "status": "success", "updated": 3, "packages": [{"name": "linux", "old_version": "6.8.1-1", "new_version": "6.8.2-1"}]}
```

### list

```bash
mowmo list
```

```json
{"command": "list", "status": "success", "count": 342, "packages": [{"name": "base", "version": "3-2"}]}
```

### info

```bash
mowmo info <package>
```

```json
{"command": "info", "package": "firefox", "status": "success", "version": "127.0.2-1", "description": "...", "url": "...", "installed": true, "size": "234.5 MiB", "depends": ["dbus-glib", "gtk3"]}
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Package not found |
| 2 | Dependency conflict |
| 3 | Permission denied |
| 4 | Network error |
| 5 | Disk space insufficient |
| 99 | Unknown error |
