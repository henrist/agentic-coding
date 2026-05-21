# AGENTS.md

## Repository overview

Infrastructure for sandboxed agentic coding: sandbox tooling, credential
injection, and user-specific rules. Not a library or app.

### Structure

```
rules.md              # Cross-repo agent conventions (referenced by multiple tools)
safe.sh               # Safehouse sandbox wrapper
credential-server     # Python credential server (runs outside sandbox)
bin/gh                # gh wrapper (runs inside sandbox)
bin/aws               # aws wrapper (runs inside sandbox)
bin/az                # az wrapper (runs inside sandbox)
bin/ssh               # ssh wrapper — gates SSH agent access (runs inside sandbox)
bin/docker            # docker wrapper -- gates access via socket proxy (runs inside sandbox)
bin/uv                # uv wrapper -- enables keyring auth via credential-server (runs inside sandbox)
bin/pip               # pip wrapper -- enables keyring auth via credential-server (runs inside sandbox)
bin/keyring           # keyring CLI bridge for uv/pip netrc credentials (runs inside sandbox)
bin/git-credential-helper  # git credential helper (runs inside sandbox)
bin/osascript         # osascript wrapper (neutered inside sandbox)
remote/aws            # aws wrapper for a remote host (vendored into hsw-iac)
```

## Workflow

Commit after completing work. Ask before committing if unsure whether
the change belongs in the repo.

This is a public repo. Never commit sensitive details (tokens, passwords,
internal hostnames, account IDs, etc.) without asking first.

## Build / test / lint

None. Verify changes manually:

```bash
./credential-server &
./safe.sh gh auth status
./safe.sh aws --profile <profile> sts get-caller-identity
```

## Code style

### Shell (bash)

- `#!/bin/bash` with `set -eu`
- Quote all variables: `"$var"`, `"$@"`
- `[[ ]]` for conditionals, not `[ ]`
- Derive paths from script location: `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`
- Find real binaries by walking PATH, skipping own directory
- `exec` for final command — don't fork unnecessarily
- Errors to stderr: `echo "Error: ..." >&2`
- Graceful fallback when credential server isn't running (run unauthenticated)

### Python (credential-server)

- Python 3, stdlib only — no external dependencies
- Imports: stdlib grouped alphabetically, one per line
- Type hints in docstrings, not annotations
- ANSI escape codes via named constants (`DIM`, `BOLD`, `GREEN`, etc.)
- Catch specific exceptions, never bare `except:`
- Signal handlers for cleanup (SIGINT, SIGTERM)

### General

- Concise over verbose. Simple over clever.
- LF line endings only.
- No em dashes (—) in code or comments. Use regular dashes or reword.

## Credential server protocol

JSON over Unix socket (`.credential-server.sock`). One request-response per connection.

```
Request:  {"type": "gh"}\n
Request:  {"type": "aws", "profile": "my-profile"}\n
Request:  {"type": "az"}\n
Request:  {"type": "ssh"}\n
Request:  {"type": "docker"}\n
Request:  {"type": "netrc", "machine": "pypi.fury.io"}\n
Request:  {"type": "aws", "profile": "p", "origin": "remote", "host": "...", "cmd": "...", "cwd": "..."}\n
Response: {"ok": true, "token": "gho_..."}\n
Response: {"ok": true, "access_key_id": "...", "secret_access_key": "...", "session_token": "..."}\n
Response: {"ok": false}\n
```

Approval is per `(safehouse_pid, cred_key)`. Cred key: `"gh"`, `"aws:<profile>"`, `"az"`, `"ssh"`, `"docker"`, or `"netrc:<machine>"`.
Approving one credential doesn't approve others.

Two-keypress approval: first select mode (`Enter`=once, `d`=deny, `r`=reads, `p`=pattern+reads, `a`=all), then duration for r/p/a (`1`=1min, `5`=5min, `s`=session). Only one approval active per context.

By default, git/gh reads and non-protected-branch pushes (not main/master) are auto-approved.
Disable with `--no-auto-git-reads` or `--no-auto-git-push`.

Docker reads (`docker ps`, `docker images`, etc.) are auto-approved by default.
Disable with `--no-auto-docker-reads`.

Netrc credential requests (for `uv` private indexes) are auto-approved by default.
Disable with `--no-auto-netrc`.

### Remote mode

A remote host (e.g. `coding26`) can request AWS credentials by SSH-forwarding
`.credential-server.sock` to itself (`ssh -R`) and running the credential-aware
`aws` wrapper `remote/aws` there. Over the forwarded socket the server's process
introspection only sees the local `ssh` client, so the wrapper self-reports
its context with extra request fields:

- `origin: "remote"` switches the server to remote mode.
- `host` scopes approvals to a synthetic `(remote:<host>, cred_key)` key
  (sanitized to `[A-Za-z0-9._-]`, capped at 64 chars).
- `cmd` / `cwd` are shown in the approval prompt and audit log; `cmd` drives
  read-only / sensitive classification.

Remote mode serves `aws` only. Remote approvals are not persisted to
`.approvals.toml`; an `r`/`p`/`a` "session" approval lasts until the server
restarts. The two-keypress approval UX is otherwise identical to local.

### Adding new credential types

1. Add fetch function in `credential-server` (e.g. `fetch_xyz_token()`)
2. Handle new type in `handle_request()` and `_fetch_creds()`
3. Create `bin/xyz` wrapper following `bin/gh` pattern
4. Mount needed read-only config in `safe.sh` (`--add-dirs-ro=...`)

Note: `az` is approval-only (no credential injection) — it reads tokens from `~/.azure` directly.
`ssh` is approval-only — it gates access to `SSH_AUTH_SOCK` (the SSH agent socket).
The wrapper strips `SSH_AUTH_SOCK` by default and restores it only if approved.
`docker` is approval-only with socket proxy -- the real Docker socket (`/var/run/docker.sock`)
is never mounted in the sandbox. The credential server creates a proxy socket
(`.docker-proxy.sock`) and only forwards connections from approved processes.
This is a hard security boundary, not just a PATH-based gate.

## Security model

- Credentials NEVER live in the sandbox. Injected per-process via env vars
  scoped to the single CLI invocation.
- Credential server runs OUTSIDE sandbox with full host access.
- `bin/` wrappers run INSIDE sandbox with restricted filesystem.
- `~/.config/gh` and `~/.aws/config` mounted read-only (config only, no secrets).
- Keychain, SSO cache, and credential files NOT accessible from sandbox.
- `aws` wrapper strips `--profile` to avoid SSO lookup in sandbox; extracts
  region/output from config and injects as `AWS_DEFAULT_REGION`/`AWS_DEFAULT_OUTPUT`.
- Remote mode: the server can't introspect a remote requester's process, so it
  trusts the wrapper's self-reported `cmd`/`cwd`/`host`. These are advisory
  (prompt display, audit log, read/sensitive classification) — they never
  narrow the returned credentials. Returned STS creds are full creds for the
  profile, so a remote `r`/`a`-mode approval means "this host may do anything
  with this profile until it expires". The real boundary is who can reach the
  forwarded socket.

## Sandbox (safe.sh)

[Agent Safehouse](https://agent-safehouse.dev/) — macOS kernel-level sandbox,
deny-by-default filesystem. `safe.sh` grants:

- Read-write: `~/Code/henrist/agentic-coding`, `~/.claude`, plus cwd project dir if in allowlist
- Read-only: `~/.gitignore`, `~/.config/gh`, `~/.aws/config`
- PATH: prepends `bin/` for credential wrappers

Modify `safe.sh` to add new directories or integrations.

### Inspecting the sandbox policy

Dump the active sandbox policy to stdout (non-interactive):

```bash
SAFEHOUSE_POLICY=1 ./safe.sh true
```

The policy is a macOS sandbox profile (Seatbelt `.sb` format) showing
all allow/deny rules. Use this to verify what the sandbox permits.

### Debugging sandbox denials

When something fails inside the sandbox, check macOS unified log for Seatbelt violations:

```bash
/usr/bin/log show --last 15m --predicate 'process == "sandboxd"' --info --debug 2>&1 | grep -i "deny\|violat"
```

Each violation shows the process, operation, and target. Fix by adding
allow rules to the appropriate profile in `profiles/`.
