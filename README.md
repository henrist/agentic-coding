# agentic-coding

My personal setup for sandboxed agentic coding — sandbox tooling, credential injection, and shared agent rules.

> **Note:** This is a personal configuration repo, not a reusable tool. Paths and preferences are hardcoded to my environment. Sharing it as reference for others building similar setups.

- `rules.md` — shared agent rules referenced by multiple AI coding tools
- `safe.sh` + `credential-server` — sandboxed execution with on-demand credential injection
- `bin/` — CLI wrappers (`gh`, `aws`, `az`, `ssh`, `docker`, `git-credential-helper`) for credential-aware tools inside the sandbox

## Rules

`rules.md` contains cross-repo conventions (commit style, plans, GitHub, etc.) shared across
AI coding tools via symlinks and references:

- `~/AGENTS.md` → symlink (Claude Code, general)
- `~/.claude/CLAUDE.md` → `@` reference (Claude Code)
- `~/.codex/AGENTS.md` → `@` reference (Codex)
- `~/.config/opencode/AGENTS.md` → symlink (OpenCode)

## Sandbox

Run commands inside [Agent Safehouse](https://agent-safehouse.dev/) with deny-by-default filesystem access.

```bash
# Run any command in the sandbox
./safe.sh <command> [args...]

# Examples
./safe.sh opencode
./safe.sh claude --dangerously-skip-permissions
```

## Credential server

Credentials (`gh`, `aws`, `git`) are injected on-demand via a Unix socket with interactive approval.
`az` uses approval-only gating (no credential injection — it reads tokens from `~/.azure` directly).
Tokens never live in the sandbox environment — they only exist in the CLI process memory during API calls.

### Setup

Start the credential server in a separate terminal:

```bash
./credential-server
```

Then use `gh` / `aws` inside the sandbox. Each credential request prompts with a two-keypress approval:

**Step 1 — mode:**
- **Enter** — allow once
- **d** / **Esc** — deny
- **r** — reads (auto-approve read-only commands)
- **p** — pattern+reads (auto-approve reads + writes matching command pattern)
- **a** — all (auto-approve everything)

**Step 2 — duration (for r/p/a):**
- **1** — 1 minute
- **5** — 5 minutes
- **s** — session (until sandbox exits)

Approvals are scoped per-sandbox and per-credential (e.g. approving `aws:dev` doesn't approve `aws:admin`; SSH is scoped per-host, so each `ssh <host>` is approved independently). Only one approval is active per context at a time — selecting a new mode replaces the previous one.

By default, git/gh reads and non-protected-branch pushes are auto-approved without prompting:
- **Reads**: `git fetch/pull/clone`, `gh pr list/view/diff`, etc.
- **Pushes**: `git push` (not to main/master), `gh pr create/edit/close`
- Disable with `--no-auto-git-reads` or `--no-auto-git-push`

Additional auto-approvals can be configured in `config.toml` (not committed):

```toml
[auto-approve]
aws-profiles = ["dev", "staging"]
```

Listed AWS profiles are auto-approved without prompting, including sensitive commands.
The server prints active auto-approved profiles on startup.

Extra sandbox settings can be configured in `config.toml`:

```toml
[sandbox]
env-pass = ["OPENCODE_EXPERIMENTAL_LSP_TY"]
allowed-dirs = ["/Users/me/Code/myorg"]  # cwd-gated read-write dirs
add-dirs = ["/Users/me/.myapp"]            # always read-write
add-dirs-ro = ["/opt/mytools"]             # always read-only
```

### GitHub CLI

```bash
./safe.sh gh auth status
./safe.sh gh pr list
```

### AWS CLI

Use `--profile` to specify the AWS profile. The server fetches temporary STS credentials
outside the sandbox and injects them as env vars:

```bash
./safe.sh aws --profile dev sts get-caller-identity
```

Requires an active SSO session (`aws sso login --profile <profile>` outside the sandbox).

### Docker

Docker access is proxied through the credential server — the real Docker socket is never mounted
inside the sandbox. The server creates `.docker-proxy.sock` and forwards approved requests to the
host Docker daemon.

```bash
./safe.sh docker ps
./safe.sh docker build -t myapp .
```

### SSH

The SSH wrapper strips `SSH_AUTH_SOCK` by default. Agent access is only restored if approved
through the credential server, preventing unauthorized key signing.

### Approval persistence

Active approvals are persisted to `.approvals.toml` and restored on server restart.
Expired and stale entries (dead PIDs) are pruned automatically on load.

### How it works

1. `credential-server` listens on `.credential-server.sock` outside the sandbox
2. `bin/gh`, `bin/aws`, and `bin/git-credential-helper` intercept CLI calls inside the sandbox
3. Wrappers request credentials via JSON protocol, server prompts for approval
4. If approved, credentials are set as env vars for just that CLI process
5. Without the server running, CLIs run unauthenticated (no error, just no auth)
