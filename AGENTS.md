# AGENTS.md

## Repository overview

Infrastructure for sandboxed agentic coding: sandbox tooling, credential
injection, and user-specific rules. Not a library or app.

### Structure

```
rules.md              # Cross-repo agent conventions (symlinked into other repos)
safe.sh               # Safehouse sandbox wrapper
credential-server     # Python credential server (runs outside sandbox)
bin/gh                # gh wrapper (runs inside sandbox)
bin/aws               # aws wrapper (runs inside sandbox)
```

## Workflow

Commit after completing work. Local-only repo — no remote, no PR.
Ask before committing if unsure whether the change belongs in the repo.

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

## Credential server protocol

JSON over Unix socket (`.credential-server.sock`). One request-response per connection.

```
Request:  {"type": "gh"}\n
Request:  {"type": "aws", "profile": "my-profile"}\n
Response: {"ok": true, "token": "gho_..."}\n
Response: {"ok": true, "access_key_id": "...", "secret_access_key": "...", "session_token": "..."}\n
Response: {"ok": false}\n
```

Approval is per `(safehouse_pid, cred_key)`. Cred key: `"gh"` or `"aws:<profile>"`.
Approving one credential doesn't approve others.

### Adding new credential types

1. Add fetch function in `credential-server` (e.g. `fetch_xyz_token()`)
2. Handle new type in `handle_request()` and `_fetch_creds()`
3. Create `bin/xyz` wrapper following `bin/gh` pattern
4. Mount needed read-only config in `safe.sh` (`--add-dirs-ro=...`)

## Security model

- Credentials NEVER live in the sandbox. Injected per-process via env vars
  scoped to the single CLI invocation.
- Credential server runs OUTSIDE sandbox with full host access.
- `bin/` wrappers run INSIDE sandbox with restricted filesystem.
- `~/.config/gh` and `~/.aws/config` mounted read-only (config only, no secrets).
- Keychain, SSO cache, and credential files NOT accessible from sandbox.
- `aws` wrapper strips `--profile` to avoid SSO lookup in sandbox; extracts
  region/output from config and injects as `AWS_DEFAULT_REGION`/`AWS_DEFAULT_OUTPUT`.

## Sandbox (safe.sh)

[Agent Safehouse](https://agent-safehouse.dev/) — macOS kernel-level sandbox,
deny-by-default filesystem. `safe.sh` grants:

- Read-write: `~/coding-agents`, `~/.claude`, plus cwd project dir if in allowlist
- Read-only: `~/.gitignore`, `~/.config/gh`, `~/.aws/config`
- PATH: prepends `bin/` for credential wrappers

Modify `safe.sh` to add new directories or integrations.
