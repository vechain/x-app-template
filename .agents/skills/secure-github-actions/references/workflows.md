# Workflow Hardening Reference

## Quick checklist

- Pin every external `uses:` reference to a full 40-character SHA.
- Do not guess SHAs.
- Prefer `pull_request` over `pull_request_target`.
- Declare explicit `permissions:`.
- Pass `github.*`, `inputs.*`, and other dynamic values into `run:` via `env:`.
- Prefer fewer third-party actions.
- Add Dependabot updates for `github-actions`.
- Remember that SHA pinning is necessary but not sufficient: pinned actions can still depend on mutable actions internally.

## Pinning rules

Pin both step-level actions and job-level reusable workflows:

```yaml
- uses: actions/checkout@<FULL_40_CHAR_SHA> # v4.3.1
- uses: aquasecurity/trivy-action@<FULL_40_CHAR_SHA> # v0.28.0

jobs:
  ci:
    uses: owner/repo/.github/workflows/reusable.yml@<FULL_40_CHAR_SHA> # v1.2.0
```

Do not leave mutable refs in place:

```yaml
# BAD
- uses: actions/checkout@v4
- uses: aquasecurity/trivy-action@main
- uses: owner/repo/.github/workflows/reusable.yml@v1
```

- Local actions like `./.github/actions/foo` do not need pinning.
- Short SHAs are not enough. Use all 40 characters.
- If you cannot verify the exact SHA in the current environment, stop and tell the user.

## Prefer fewer dependencies

- Before adding a third-party action, ask whether plain `run:` or a GitHub-maintained action is enough.
- Treat scanners, deploy or publish actions, artifact or comment actions, and credential-handling actions as especially sensitive.

## Events and permissions

- Prefer `pull_request` for untrusted fork contributions.
- Avoid `pull_request_target` unless the workflow only performs safe, non-executing metadata tasks.
- Set explicit `permissions:`. Common safe default:

```yaml
permissions:
  contents: read
```

- Grant write scopes only per job when required.

## Shell injection safety

Bad:

```yaml
- run: echo "${{ github.event.pull_request.title }}"
```

Good:

```yaml
- env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "$PR_TITLE"
```

Apply the same pattern to `github.head_ref`, `github.ref_name`, `inputs.*`, `matrix.*`, and any value that can contain spaces or shell metacharacters. Quote variables in shell and prefer small scripts over dense one-liners.

## Dependabot

Use `.github/dependabot.yml` to keep pinned SHAs current:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

Review updates before merging. Keep the human version hint in comments so reviewers can map a SHA back to a release.

## Review prompts

When auditing workflows, actively search for:

- `@v`, `@main`, `@master`, or short SHAs in any `uses:` line
- `pull_request_target`
- Missing or overly broad `permissions:`
- Direct `${{ ... }}` interpolation inside `run:`
- `secrets: inherit` instead of explicit secrets
- Unnecessary third-party actions
