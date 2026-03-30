- In all interactions and commit messages, be concise and sacrifice grammar for the sake of concision.
- Prefer consistency and conciseness.
- Tell me if I'm about to add accidental complexity.
- Avoid clever code. Avoid accidental complexity. Focus on simple and readable code.
- Always ask me to perform any "rm -rf" commands, or delete individual files/folders instead on your own.
- Don't accidentally introduce CRLF endings.
- Always use pnpx instead of npx.
- Follow the principle of less is more - keep things simple.
- Bash scripts: Reserve uppercase for system and environment variables

## Plans

- Avoid leaving out crucial details of the plan. Assume I will run the plan using cleaned context.
- At the end of each plan, list unresolved questions. Ask about edge cases, error handling, and unclear requirements before proceeding.
- End every plan with a numbered list of concrete steps. This should be the last thing visible in the terminal.

## Git commits

When creating a Git commit:

- Prefer short and concise commit titles, ideally 50 chars or less
- Capitalize first letter of commit title, unless using conventional commit prefixes (fix:, feat:, etc.) or starting with an identifier that is normally lowercase
- Message body should primarily focus on _why_ a change is being made. Focus on details that gives clarity and context
- Avoid adding a verbose commit message/body, unless it is necessary for clarity or documentation.
- If adding a message/body, focus on the changes made and why they are important.
- Look through the recent changes and prefer consistency.

Avoid amending commits that is pushed to the remote. Always check this before considering to amend.

Don't `git pull --rebase` when the branch has merge commits — it replays merged-in commits on top, breaking history. Use `git pull` (merge) instead.

## GitHub

- Prefer the GitHub CLI (`gh`) to interact with GitHub for our own repositories. Use https for public stuff.
- Keep PR descriptions short and concise.

## GitHub Actions

When referencing GitHub Actions by tag, you must always check for latest version,
unless you are told to use a specific tag.

If a tag is already used in the same repo, prefer reusing it.

Check for the tag list and prefer using only the latest major tag.
E.g. for actions/checkout it would be https://github.com/actions/checkout/tags

## PNPM

When setting up a new PNPM project, always include in `pnpm-workspace.yaml`:

```yaml
minimumReleaseAge: 4320
```

`minimumReleaseAge: 4320` ensures packages must be published for at least 3 days before they can be installed, protecting against supply chain attacks.

## Node.js

Assume Node.js 24+ with native TypeScript execution (strip types) unless the project indicates otherwise. No need for ts-node or tsx as a dev dependency for running scripts.
