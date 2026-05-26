# Security Audit Checklist

Run every check when performing a full security audit. Group findings by severity.

## Phase 1: Secrets Scanning

### 1.1 Gitleaks

```bash
gitleaks detect --source . -v --report-path /tmp/gitleaks-report.json
```

Install if missing: `brew install gitleaks`

### 1.2 TruffleHog

```bash
trufflehog git file://. --json > /tmp/trufflehog-report.json
```

Install if missing: `brew install trufflehog`

TruffleHog attempts to **verify** secrets. Findings with `"verified": true` are live, exploitable credentials -- treat as CRITICAL.

### 1.3 Classify findings

- **Verified live secret** (trufflehog verified=true): CRITICAL
- **Real-looking unverified secret** (API key, token, password): HIGH
- **Example/placeholder in .env.example**: FALSE POSITIVE (`NEXT_PUBLIC_*` keys are client-side)
- **Local dev credential** (localhost passwords, test mnemonics): LOW
- **Package integrity hash** (yarn.lock SHA-1): FALSE POSITIVE

### 1.4 Manual pattern search (current HEAD)

```bash
grep -rn "AKIA" --include="*.ts" --include="*.js" --include="*.json" --include="*.yml" --include="*.env*" . | grep -v node_modules
grep -rn "ghp_\|gho_\|github_pat_" --include="*.ts" --include="*.js" --include="*.json" . | grep -v node_modules
find . -name "*.pem" -o -name "*.key" -o -name "*.p12" | grep -v node_modules | grep -v .git
git ls-files | grep -i "\.env" | grep -v example | grep -v template
```

## Phase 2: Sensitive Files

### 2.1 Tracked files that should not be

```bash
git ls-files | grep -E "\.tfstate|terraform\.tfvars"
find . -name "*.sqlite" -o -name "*.db" | grep -v node_modules | grep -v .git
```

### 2.2 .gitignore completeness

Verify these patterns exist: `.env`, `.env.*`, `!.env.example`, `node_modules/`, `*.tfstate`, `*.tfvars`, `.terraform/`, `coverage/`, `dist/`, `build/`

### 2.3 Large binary files

```bash
find . -not -path "*/.git/*" -not -path "*/node_modules/*" -size +1M -type f
```

## Phase 3: GitHub Actions Security

### 3.1 Zizmor scan

High-severity, high-confidence findings (recommended for audits):

```bash
zizmor --min-severity high --min-confidence high --persona auditor .github/workflows/*
```

Broader scan including medium findings:

```bash
zizmor --min-severity medium --min-confidence medium --persona auditor .github/workflows/*
```

Auto-fix safe issues:

```bash
zizmor --min-severity medium --min-confidence high --persona auditor .github/workflows/* --fix safe
```

Install if missing: `brew install woodruffw/tap/zizmor`

### 3.2 Permissions audit

```bash
for f in .github/workflows/*.yml .github/workflows/*.yaml; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  if grep -q "permissions" "$f"; then
    echo "OK: $name"
  else
    echo "MISSING: $name -- inherits repo default (likely write-all)"
  fi
done
```

### 3.3 Dangerous trigger patterns

```bash
grep -rn "pull_request_target" .github/workflows/
grep -rn "workflow_run" .github/workflows/
grep -rn '\${{.*github\.event\.\(issue\|pull_request\|comment\|review\)' .github/workflows/
```

### 3.4 Secrets inheritance

```bash
grep -rn "secrets: inherit" .github/workflows/
```

### 3.5 Self-hosted runners

```bash
grep -rn "self-hosted\|runs-on.*self" .github/workflows/
```

Self-hosted runners in public repos = CRITICAL risk.

### 3.6 Third-party action inventory

```bash
grep -rh "uses:" .github/workflows/ | grep -v "#" | grep -v "\./" | sed 's/.*uses: //' | sed 's/@.*//' | sort -u
```

### 3.7 Concurrency guards

Verify deploy and infrastructure workflows have `concurrency:` settings.

## Phase 4: Repository Configuration

### 4.1 Required files for public repos

| File | Purpose |
|------|---------|
| `LICENSE` | Legal framework |
| `SECURITY.md` | Vulnerability reporting |
| `CODEOWNERS` | Mandatory reviewers for sensitive paths |
| `.github/dependabot.yml` | Automated dependency updates |

### 4.2 Internal references

```bash
grep -rn "slack\.com\|confluence\|jira\.\|notion\.so" --include="*.ts" --include="*.js" --include="*.md" . | grep -v node_modules
```

### 4.3 Infrastructure exposure

```bash
grep -rn "arn:aws" --include="*.tf" --include="*.yaml" . | grep -v node_modules
grep -rn "secrets\." .github/workflows/ | sed 's/.*secrets\./secrets./' | sort -u
```

NOTE: AWS account IDs and VPC IDs are not secrets. Flag for awareness, not as CRITICAL.

## Phase 5: Report

Present findings using this format:

```markdown
## Security Audit Report -- [repo-name]

**Date:** YYYY-MM-DD | **Tools:** gitleaks, trufflehog, zizmor

| Severity | Count |
|----------|-------|
| CRITICAL | X |
| HIGH     | X |
| MEDIUM   | X |
| LOW      | X |

### Findings

#### CRITICAL

1. [Title] -- [file:line] -- [description] -- [remediation]

### Action Items (Priority Order)

1. ...
```
