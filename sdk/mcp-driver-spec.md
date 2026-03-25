# MCP Driver Interface Specification

**Version:** v1.0
**Status:** Normative
**Applies to:** Mohjave OS kernel <-> driver interface

---

## Overview

This document defines the Model Context Protocol (MCP) driver interface for Mohjave OS. An MCP driver is a standalone process that exposes one or more tools to the kernel via a structured stdio-based protocol. Drivers are spawned by the kernel, communicate exclusively over stdin/stdout using JSON lines, and are subject to sandboxing and resource constraints enforced by the kernel.

---

## 1. Tool Registration Protocol

Upon startup, a driver MUST write one or more registration messages to stdout before any other output. Each registration message declares a single tool. The kernel reads registration messages until it receives a `registration_complete` message.

### Registration Message Format

```json
{
  "type": "tool_registration",
  "tool": {
    "name": "string",
    "description": "string",
    "parameters": { }
  }
}
```

| Field                  | Type   | Required | Description                                                        |
|------------------------|--------|----------|--------------------------------------------------------------------|
| `type`                 | string | yes      | Must be `"tool_registration"`.                                     |
| `tool.name`            | string | yes      | Unique tool name within the driver namespace. Must match `[a-z][a-z0-9_]{0,62}`. |
| `tool.description`     | string | yes      | Human-readable description of the tool (max 256 characters).       |
| `tool.parameters`      | object | yes      | A valid JSON Schema object describing the tool's input parameters. |

### Registration Complete Message

After all tools have been registered, the driver MUST emit:

```json
{
  "type": "registration_complete"
}
```

### Full Registration Example

A driver that exposes two tools would write the following three lines to stdout (one JSON object per line, no trailing commas, no pretty-printing):

```json
{"type":"tool_registration","tool":{"name":"read_file","description":"Read the contents of a file at the given path.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute file path to read."}},"required":["path"],"additionalProperties":false}}}
{"type":"tool_registration","tool":{"name":"write_file","description":"Write content to a file, creating or overwriting it.","parameters":{"type":"object","properties":{"path":{"type":"string","description":"Absolute file path to write."},"content":{"type":"string","description":"Content to write to the file."}},"required":["path","content"],"additionalProperties":false}}}
{"type":"registration_complete"}
```

The kernel will reject the driver if:

- No `registration_complete` message is received within 10 seconds of process start.
- Any `tool.name` collides with an already-registered tool in the same namespace.
- More than 10 tools are registered (see Section 5).
- The `parameters` value is not a valid JSON Schema.

---

## 2. Stdio Transport Format

All communication between the kernel and the driver uses **JSON lines** over standard I/O:

- **stdin** (kernel -> driver): The kernel writes messages to the driver's stdin.
- **stdout** (driver -> kernel): The driver writes messages to its stdout.
- **stderr**: Reserved for unstructured diagnostic logs. The kernel captures stderr but does not parse it.

Each message is a single line of JSON terminated by `\n`. Messages MUST NOT span multiple lines.

### Message Types

#### 2.1 `tool_call` (kernel -> driver)

Sent by the kernel when a tool invocation is requested.

```json
{
  "type": "tool_call",
  "id": "call_a1b2c3d4",
  "tool": "read_file",
  "arguments": {
    "path": "/etc/hostname"
  }
}
```

| Field       | Type   | Required | Description                                             |
|-------------|--------|----------|---------------------------------------------------------|
| `type`      | string | yes      | Must be `"tool_call"`.                                  |
| `id`        | string | yes      | Unique call identifier assigned by the kernel.          |
| `tool`      | string | yes      | Name of the tool to invoke (must match a registered tool). |
| `arguments` | object | yes      | Arguments conforming to the tool's parameter JSON Schema. |

#### 2.2 `tool_result` (driver -> kernel)

Sent by the driver upon completion of a tool call.

**Success:**

```json
{
  "type": "tool_result",
  "id": "call_a1b2c3d4",
  "status": "success",
  "output": "mohjave-desktop\n"
}
```

**Error:**

```json
{
  "type": "tool_result",
  "id": "call_a1b2c3d4",
  "status": "error",
  "error": {
    "code": "FILE_NOT_FOUND",
    "message": "No such file: /etc/nonexistent"
  }
}
```

| Field           | Type   | Required         | Description                                              |
|-----------------|--------|------------------|----------------------------------------------------------|
| `type`          | string | yes              | Must be `"tool_result"`.                                 |
| `id`            | string | yes              | Must match the `id` from the corresponding `tool_call`.  |
| `status`        | string | yes              | Either `"success"` or `"error"`.                         |
| `output`        | string | if status=success | The tool's output content (max 4096 tokens; see Section 5). |
| `error`         | object | if status=error   | Error details.                                           |
| `error.code`    | string | yes (in error)    | Machine-readable error code.                             |
| `error.message` | string | yes (in error)    | Human-readable error description.                        |

#### 2.3 Ordering and Concurrency

The kernel MAY send multiple `tool_call` messages before receiving corresponding `tool_result` messages. Drivers MAY process calls concurrently, but each `tool_result` MUST reference its originating `id`. Results may be returned in any order.

---

## 3. Health Check Protocol

The kernel periodically verifies that a driver process is responsive by issuing health checks.

### Health Check Message (kernel -> driver)

```json
{
  "type": "health_check",
  "id": "hc_00001"
}
```

### Health OK Response (driver -> kernel)

```json
{
  "type": "health_ok",
  "id": "hc_00001"
}
```

| Field  | Type   | Required | Description                                                |
|--------|--------|----------|------------------------------------------------------------|
| `type` | string | yes      | `"health_check"` for the request, `"health_ok"` for the response. |
| `id`   | string | yes      | Opaque identifier. The response MUST echo the same `id`.  |

### Timeout Behavior

- The driver MUST respond with `health_ok` within **5 seconds** of receiving a `health_check`.
- If the driver fails to respond within the deadline, the kernel considers the driver **unresponsive**.
- After **3 consecutive missed health checks**, the kernel terminates the driver process (following the shutdown procedure in Section 4) and marks all its tools as unavailable.
- Health checks are sent at a default interval of 30 seconds. This interval is not configurable by the driver.

### Health Check During Tool Execution

Health check messages may arrive while a tool call is in progress. The driver MUST still respond to health checks promptly, independent of any ongoing tool execution. Drivers should avoid blocking their stdin read loop on long-running tool work.

---

## 4. Graceful Shutdown

The kernel uses a two-phase shutdown sequence to terminate driver processes.

### Lifecycle

1. **SIGTERM sent.** The kernel sends `SIGTERM` to the driver process. This signals that the driver should begin an orderly shutdown.

2. **Grace period (10 seconds).** The driver has 10 seconds to:
   - Finish any in-progress tool calls and write their `tool_result` messages.
   - Flush all buffered stdout/stderr output.
   - Release any held resources (file handles, temporary files, network connections).
   - Exit with code 0.

3. **SIGKILL sent.** If the driver process has not exited after 10 seconds, the kernel sends `SIGKILL` to forcibly terminate it. Any in-flight tool calls are considered failed, and the kernel synthesizes error results for them:

   ```json
   {
     "type": "tool_result",
     "id": "call_a1b2c3d4",
     "status": "error",
     "error": {
       "code": "DRIVER_TERMINATED",
       "message": "Driver process was terminated during execution."
     }
   }
   ```

### Driver Expectations

- Drivers MUST install a `SIGTERM` handler (or rely on default behavior that leads to a clean exit).
- Drivers SHOULD attempt to complete in-flight work within the grace period rather than abandoning it immediately.
- Drivers MUST NOT ignore `SIGTERM` indefinitely. A driver that catches `SIGTERM` but fails to exit will be killed after the grace period.
- On clean exit, the driver SHOULD exit with code 0. A non-zero exit code is logged by the kernel as a warning.

### Kernel-Initiated Restart

After a driver is terminated (gracefully or forcibly), the kernel MAY restart it automatically if the driver is declared as `restart: always` in its manifest. Restarted drivers go through the full registration sequence again.

---

## 5. Constraints

The following constraints are enforced by the Mohjave OS kernel on all MCP drivers.

### 5.1 One Process per Namespace

Each driver namespace is served by exactly one OS process. A namespace corresponds to the driver's declared name in its manifest. The kernel will not spawn a second instance of a driver while an existing instance is running in the same namespace.

### 5.2 Maximum 10 Tools per Driver

A single driver process may register at most **10 tools**. If the driver attempts to register more than 10 tools before sending `registration_complete`, the kernel rejects the driver and terminates it.

### 5.3 Execution Timeout (60 seconds)

Each individual tool call has a maximum execution time of **60 seconds**. If the driver does not return a `tool_result` for a given `tool_call` within 60 seconds of dispatch, the kernel:

- Cancels the call.
- Synthesizes an error result:

  ```json
  {
    "type": "tool_result",
    "id": "call_timed_out",
    "status": "error",
    "error": {
      "code": "EXECUTION_TIMEOUT",
      "message": "Tool execution exceeded the 60 second timeout."
    }
  }
  ```

- The driver process is NOT terminated solely due to a timeout. It may continue serving subsequent calls.

### 5.4 Output Token Ceiling (4096 tokens)

The `output` field in a successful `tool_result` must not exceed **4096 tokens**. Token counting uses the kernel's tokenizer. If the output exceeds this limit, the kernel truncates the output and appends a truncation notice. Drivers SHOULD proactively limit their output to stay within this ceiling.

### 5.5 Network Access Requires Manifest Declaration

Drivers are sandboxed by default with **no network access**. To make outbound network requests, the driver's manifest MUST include an explicit network permission declaration:

```json
{
  "name": "example-driver",
  "permissions": {
    "network": {
      "allow": ["api.example.com:443", "192.168.1.0/24:8080"]
    }
  }
}
```

The kernel enforces network restrictions at the sandbox level. Any undeclared network access attempt is blocked and logged.

### 5.6 systemd-nspawn Sandbox (per Constitution Art. IV)

Every driver process runs inside a **systemd-nspawn** container, as mandated by Mohjave OS Constitution Article IV. The sandbox provides:

- **Filesystem isolation.** The driver sees a minimal root filesystem. Only explicitly mounted paths (declared in the manifest) are available.
- **PID namespace isolation.** The driver cannot see or signal processes outside its container.
- **Network namespace isolation.** Network access is denied unless declared (see Section 5.5).
- **Resource limits.** CPU and memory cgroups are applied per the driver's manifest resource declarations.
- **No privilege escalation.** The driver runs as an unprivileged user inside the container. `CAP_SYS_ADMIN` and other dangerous capabilities are dropped.

Drivers MUST NOT assume access to the host filesystem, host network, or host process tree. All external access is mediated through the manifest and enforced by the nspawn sandbox.

---

## Appendix: Message Type Summary

| Message Type            | Direction         | Description                        |
|-------------------------|-------------------|------------------------------------|
| `tool_registration`     | driver -> kernel  | Register a single tool.            |
| `registration_complete` | driver -> kernel  | Signal end of registration phase.  |
| `tool_call`             | kernel -> driver  | Invoke a registered tool.          |
| `tool_result`           | driver -> kernel  | Return result of a tool invocation.|
| `health_check`          | kernel -> driver  | Liveness probe.                    |
| `health_ok`             | driver -> kernel  | Liveness response.                 |
