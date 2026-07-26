- In all interactions and commit messages, be concise and sacrifice grammar for the sake of concision.
- Less is more — prefer simple, readable code; avoid clever code and accidental complexity.
- Tell me if I'm about to add accidental complexity.
- When evolving code, aim for how we'd build it from scratch today — reduce tech debt, don't layer workarounds on it.
- Don't accidentally introduce CRLF endings.
- Always use pnpm dlx instead of npx.
- Bash scripts: Reserve uppercase for system and environment variables.

## Code comments

Default: write zero comments. Comments rot, blur diffs, and add review load. The code is the source of truth — if the code can express it, the comment shouldn't.

A comment may stay only if it captures something the code cannot:

- A non-obvious WHY: hidden constraint, subtle invariant, workaround for a specific bug, perf trick that reads as wrong.
- A footgun warning.
- Required by language/tooling: public-API docstrings of a library, license headers, type-system annotations.

Never write:

- Restatements of what the code already says (`// increment counter`, `# loop over users`).
- Section banners or scaffolding headers (`// --- Setup ---`, `# Helpers`).
- Narration of the change or task (`// added retry`, `// new function`, `// refactored from X`).
- References to a PR, ticket, person, or review (`// per review`, `// fix for #123`, `// used by FooFlow`) — that belongs in the commit message or PR description.
- TODO / "future work" / hedging comments unless paired with a concrete owner or ticket.
- Multi-line docstrings on internal functions — the signature and name should carry it.

When unsure, delete it.

## Plans

- Avoid leaving out crucial details of the plan. Assume I will run the plan using cleaned context.
- List unresolved questions before the steps. Ask about edge cases, error handling, and unclear requirements before proceeding.
- End every plan with a numbered list of concrete steps. This should be the last thing visible in the terminal.

## Git commits

When creating a Git commit:

- Prefer short and concise commit titles, ideally 50 chars or less.
- Capitalize first letter of commit title, unless using conventional commit prefixes (fix:, feat:, etc.) or starting with an identifier that is normally lowercase.
- Message body should focus on *why* the change is made — clarity and context. Skip the body unless it adds value.
- Look through recent commits and prefer consistency.
- Never `git add -A` / `git add .` — stage explicit paths only. The working tree may hold unrelated WIP (e.g. from a concurrent session). Verify staged files with `git status` before committing.

Avoid amending commits already pushed to the remote — check first.

Don't `git pull --rebase` on branches with merge commits — use `git pull` (merge).

## GitHub

- Prefer the GitHub CLI (`gh`) to interact with GitHub for our own repositories.
- Keep PR descriptions short and concise.

## GitHub Actions

- Pin actions by commit SHA with the full version as a trailing comment, e.g. `uses: actions/checkout@<sha> # v1.2.3`. Look up the SHA for the latest release on the repo's tags page.
- If a version is already used elsewhere in the same repo, reuse it.

## PNPM

When setting up a new PNPM project, always include in `pnpm-workspace.yaml`:

```yaml
minimumReleaseAge: 4320
```

`minimumReleaseAge: 4320` ensures packages must be published for at least 3 days before they can be installed, protecting against supply chain attacks.

When pnpm flags dependency build scripts, mark each package as denied unless its build script is actually required. Use the config for the pnpm version in use (`allowBuilds: <pkg>: false` in v11, `ignoredBuiltDependencies` in v10). Never `pnpm approve-builds --all`.

## Node.js

Assume Node.js 24+ with native TypeScript execution (strip types) unless the project indicates otherwise. No need for ts-node or tsx as a dev dependency for running scripts.
