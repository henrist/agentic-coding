- In all interactions and commit messages, be concise and sacrifice grammar for the sake of concision.
- Prefer consistency and conciseness.
- Tell me if I'm about to add accidental complexity.
- Avoid clever code. Focus on simple and readable code.
- If you need to branch out from main, avoid changing to main branch first.
- Always ask me to perform any "rm -rf" commands, or delete individual files/folders instead on your own.
- Don't accidentally introduce CRLF endings.
- Never use npx to run arbitrary commands. Use pnpx instead, as my global config has safer rules.
- Unless I tell you to, never amend commits that is pushed to the remote. Always check this before considering to amend

## Plans

- Avoid leaving out crucial details of the plan. Assume I will run the plan using cleaned context.
- At the end of each plan, list unresolved questions. Ask about edge cases, error handling, and unclear requirements before proceeding.
- End every plan with a numbered list of concrete steps. This should be the last thing visible in the terminal.

## Git commits

When creating a Git commit:

- A commit title should be 50 chars or less, and only in exceptional cases longer but below 80 chars
- Generally a Git message should be short and contain minimal details about _what_ it is doing. Focus on details that gives clarity and context
- Be concise and don't mention Claude and don't add a co-authored-by for Claude. Less is more.
- Avoid adding a verbose commit message/body, unless it is necessary for clarity or documentation.
- If adding a message/body, focus on the changes made and why they are important.
- Look through the recent changes and prefer consistency.

When I'm on a PR branch, I prefer adding new commits instead of rebasing or amending a previous commit.

## GitHub

- Prefer the GitHub CLI (`gh` command) to interact with GitHub for our own repositories. Use https for public stuff.
- Avoid including "test plan" section in PR description.

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
