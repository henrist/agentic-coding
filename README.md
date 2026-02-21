# coding-agents

Sandboxed environment for running coding agents using [Agent Safehouse](https://agent-safehouse.dev/).

## Usage

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
- **5** — auto-approve this sandbox for 5 minutes
- **s** — auto-approve until this sandbox process exits

Approvals are scoped per-sandbox and per-credential (e.g. approving `aws:go-dev-op` doesn't approve `aws:go-prod-admin`).

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
