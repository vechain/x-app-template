---
name: secure-github-actions
description: |
  Secure GitHub Actions workflows against supply-chain, privilege, and shell-injection risks. Use when creating, scaffolding, editing, or reviewing `.github/workflows/*.yml`, reusable workflows, `action.yml`, or Dependabot config for GitHub Actions. Also use for full repository security audits ("audit my workflows", "harden this repo", "security scan", "pin actions to SHA"), secrets scanning with gitleaks and trufflehog, and pre-public-release security reviews. Enforce full 40-character commit SHA pinning, avoid `pull_request_target` on untrusted code, pass GitHub context into `run:` steps via `env:`, and set least-privilege permissions.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.2.0"
---

# Secure GitHub Actions

Create, review, and audit GitHub Actions workflows with supply-chain-safe defaults.

## CRITICAL RULES

1. **Read the relevant reference files first.** When the user's request involves any topic in the reference table below, read those files before doing anything else. Briefly mention which files you are reading so the user can confirm the skill is active.
2. **Pin every non-local `uses:` reference to a full 40-character commit SHA.** Treat `@v*`, `@main`, `@master`, branch names, and short SHAs as security debt.
3. **Never invent SHAs.** Resolve them from GitHub or ask the user; if you cannot verify the right SHA, say so explicitly instead of fabricating one.
4. **Do not introduce `pull_request_target`** unless the user explicitly requires it and the workflow never executes untrusted code with secrets or write permissions.
5. **Never splice untrusted context directly into shell.** Move `${{ github.* }}`, `${{ inputs.* }}`, and similar values into `env:` and quote the shell variable.
6. **Set explicit least-privilege `permissions:`.** Default to read-only and grant write scopes only to the specific job that needs them.
7. **Always run the full audit checklist** when asked to "audit", "harden", or "security scan" a repository.
8. **Never silently skip a check.** If a tool is missing (gitleaks, trufflehog, zizmor), report it and suggest installation.
9. **After compaction or context loss**, re-read this SKILL and the reference files before continuing.

## Operating procedure

### For writing or editing workflows

1. Classify the task: new workflow, workflow edit, reusable workflow, or security review.
2. Read [references/workflows.md](references/workflows.md) and [references/secure-patterns.md](references/secure-patterns.md).
3. Audit every `uses:` reference:
   - Local actions like `./.github/actions/foo` are fine.
   - Step-level actions and job-level reusable workflows must use full SHAs.
   - Preserve the human release label in a comment (e.g., `# v4.3.1`).
4. Audit the trust boundary:
   - Prefer `pull_request` over `pull_request_target`.
   - Assume forked PR data is untrusted.
   - Avoid exposing secrets or write tokens to untrusted code paths.
5. Audit every `run:` step:
   - Pass dynamic values through `env:`.
   - Quote shell variables.
   - Prefer simple shell over adding a new third-party action when either works.
6. Add or update maintenance guardrails:
   - Ensure Dependabot updates the `github-actions` ecosystem.
   - Call out transitive risk: pinned actions can still reference mutable actions internally.

### For full security audits

When asked to "audit", "harden", or "security scan" a repository:

1. Read [references/audit-checklist.md](references/audit-checklist.md).
2. Execute all checks, using subagents to parallelize where possible.
3. Present findings grouped by severity: CRITICAL, HIGH, MEDIUM, LOW.
4. End with a summary table and prioritized action list.

## Reference files

| Topic | File | Read when... |
|-------|------|-------------|
| Workflow hardening patterns | [references/workflows.md](references/workflows.md) | Creating, editing, or reviewing workflows |
| Secure workflow templates | [references/secure-patterns.md](references/secure-patterns.md) | Writing new workflows from scratch |
| Full audit procedure | [references/audit-checklist.md](references/audit-checklist.md) | Running a security audit on a repository |
| SHA pinning automation | [references/sha-pinning.md](references/sha-pinning.md) | Pinning actions to commit SHAs |

## Tools

The audit checks for these tools and reports missing ones:

| Tool | Purpose | Install |
|------|---------|---------|
| `gitleaks` | Scan git history for secrets | `brew install gitleaks` |
| `trufflehog` | Deep secrets scanning with verification | `brew install trufflehog` |
| `zizmor` | Static analysis for GH Actions | `brew install woodruffw/tap/zizmor` |
| `gh` | GitHub CLI for API calls | `brew install gh` |
