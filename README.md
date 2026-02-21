# coding-agents

Shared resources for agentic coding — sandbox tooling, rules, and configuration.

- `rules.md` — user-specific rules for AI coding agents (commit style, conventions, etc.)
- `safe.sh` + `credential-server` — sandboxed execution with on-demand credential injection
- `bin/` — CLI wrappers for credential-aware tools inside the sandbox

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

Credentials (`gh`, `aws`) are injected on-demand via a Unix socket with interactive approval.
Tokens never live in the sandbox environment — they only exist in the CLI process memory during API calls.

### Setup

Start the credential server in a separate terminal:

```bash
./credential-server
```

Then use `gh` / `aws` inside the sandbox. Each credential request prompts for approval (single keypress):

- **d** / **Enter** — deny
- **o** — allow once
- **1** — auto-approve for 1 minute
- **5** — auto-approve for 5 minutes
- **s** — auto-approve until sandbox exits
- **r** — read-only for 1 minute (auto-approves reads, re-prompts mutations)
- **R** — read-only for 5 minutes (auto-approves reads, re-prompts mutations)
- **e** — read-only until sandbox exits (auto-approves reads, re-prompts mutations)

Approvals are scoped per-sandbox and per-credential (e.g. approving `aws:go-dev-op` doesn't approve `aws:go-prod-admin`). Read-only modes allow credential reads (e.g., listing resources) without requiring approval for each request, but still prompt for mutations (e.g., creating or deleting resources).

### GitHub CLI

```bash
./safe.sh gh auth status
./safe.sh gh pr list
```

### AWS CLI

Use `--profile` to specify the AWS profile. The server fetches temporary STS credentials
outside the sandbox and injects them as env vars:

```bash
./safe.sh aws --profile go-dev-op sts get-caller-identity
```

Requires an active SSO session (`aws sso login --profile <profile>` outside the sandbox).

### How it works

1. `credential-server` listens on `.credential-server.sock` outside the sandbox
2. `bin/gh` and `bin/aws` wrappers intercept CLI calls inside the sandbox
3. Wrappers request credentials via JSON protocol, server prompts for approval
4. If approved, credentials are set as env vars for just that CLI process
5. Without the server running, CLIs run unauthenticated (no error, just no auth)
