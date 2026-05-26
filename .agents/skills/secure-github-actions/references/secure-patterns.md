# Secure Workflow Patterns

Apply these patterns when writing new workflows or fixing existing ones.

## Permission reference table

| Workflow type | Permissions needed |
|---------------|-------------------|
| Lint / test / build | `contents: read` |
| Deploy via OIDC | `contents: read`, `id-token: write` |
| Create release | `contents: write` |
| Comment on PR | `contents: read`, `pull-requests: write` |
| Push to GHCR | `contents: read`, `packages: write` |
| Upload SARIF | `contents: read`, `security-events: write` |
| Label PRs | `contents: read`, `pull-requests: write` |

## Explicit secrets (no `secrets: inherit`)

When calling reusable workflows, pass only the secrets needed:

```yaml
# BAD -- passes ALL repo secrets
secrets: inherit

# GOOD -- explicit, auditable
secrets:
  AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

## Concurrency guards

Deploy workflows must prevent parallel runs:

```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false  # Don't cancel in-progress deploys
```

For CI (tests, lint), cancel previous runs:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

## CODEOWNERS for workflow protection

```text
# .github/CODEOWNERS
.github/workflows/     @org/security-team @org/devops-team
.github/dependabot.yml @org/security-team
```

Combined with branch protection rules requiring CODEOWNERS approval, this prevents unauthorized workflow changes.

## Complete secure workflow template

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<FULL_40_CHAR_SHA> # v4.x.x

      - uses: actions/setup-node@<FULL_40_CHAR_SHA> # v4.x.x
        with:
          node-version-file: .nvmrc
          cache: "npm"

      - run: npm ci
      - run: npm test
```
