# SHA Pinning Reference

## Why pin to SHA

Git tags are mutable. A malicious actor who compromises an action's repository can move the `v4` tag to a different commit containing backdoored code. SHA pins are immutable and prevent supply-chain attacks.

## Manual SHA resolution

```bash
# Find latest specific version for a major tag
gh api /repos/actions/checkout/git/refs/tags/v4. --jq '.[].ref' | sort -V | tail -1

# Get SHA for that tag
gh api /repos/actions/checkout/git/refs/tags/v4.3.1 --jq '.object.sha'

# For annotated tags, dereference
SHA=$(gh api /repos/OWNER/REPO/git/refs/tags/TAG --jq '.object.sha')
TYPE=$(gh api /repos/OWNER/REPO/git/refs/tags/TAG --jq '.object.type')
if [ "$TYPE" = "tag" ]; then
  SHA=$(gh api /repos/OWNER/REPO/git/tags/$SHA --jq '.object.sha')
fi
echo $SHA
```

## Dependabot and SHA pins

Dependabot reads the version comment (`# v4.3.1`) to track pinned versions. When a new release appears, Dependabot opens a PR updating both the SHA and the comment.

Without the version comment, Dependabot cannot determine the current version and may not propose updates.

Required `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

## Specific version comments

Always use the most specific version in comments, not just the major tag:

```yaml
# GOOD -- Dependabot can track and update incrementally
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

# BAD -- Dependabot cannot determine the exact version
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4
```

To find the specific version a major tag points to, list all tags under that prefix:

```bash
gh api /repos/actions/checkout/git/refs/tags/v4. --jq '.[].ref' | sort -V | tail -1
# Output: refs/tags/v4.3.1
```
