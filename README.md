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

## GitHub CLI authentication

The `gh` CLI uses on-demand token injection via a Unix socket — the token is never stored in the sandbox environment. It only exists in the `gh` process memory during API calls.

### Setup

Start the credential server in a separate terminal **before** launching the sandbox:

```bash
./gh-token-server
```

Then use `gh` normally inside the sandbox. When you stop the server (Ctrl+C), `gh` commands lose auth immediately.

### How it works

1. `gh-token-server` listens on `.gh-token.sock` (Unix socket) outside the sandbox
2. `bin/gh` wrapper intercepts `gh` calls inside the sandbox
3. Wrapper fetches token from socket, sets `GH_TOKEN` for just the `gh` process, execs real `gh`
4. Without the server running, `gh` runs unauthenticated (no error, just no auth)
