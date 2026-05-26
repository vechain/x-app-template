---
name: x-2-earn-apps
description: Build X2Earn sustainability apps on VeBetterDAO — reward distribution, sustainability proofs, app submission, endorsement, and integration patterns.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.1.0"
---

# X2Earn Apps Skill

## CRITICAL RULES

1. **Read reference files FIRST.** When the user's request involves any topic in the reference table below, read those files before doing anything else — before writing code, before making decisions. Briefly mention which files you are reading so the user can confirm the skill is active (e.g., "Reading X2Earn integration reference...").
2. **Information priority for VeChain topics:** (a) Reference files in this skill — always the primary source. (b) VeChain MCP tools — use `@vechain/mcp-server` for on-chain data, transaction building, and live network queries; use Kapa AI MCP for VeChain documentation lookups. (c) Web search — only as a last resort, and only for topics NOT covered in the reference files.
3. **Prefer working directly in the main conversation** for VeChain tasks. Plan mode and subagents do not inherit skill context and may fall back to web search instead of using reference files.
4. **After compaction or context loss**, re-read this SKILL.md to restore awareness of the reference table and operating procedure before continuing work.

## Scope

Use this Skill for X2Earn app development on VeBetterDAO:

- Building sustainability-rewarding applications
- Distributing B3TR token rewards to users
- Sustainability proofs and impact tracking
- App submission, endorsement, and lifecycle
- Integration patterns (smart contract, backend, hybrid)
- VePassport and Sybil resistance considerations

## Operating procedure

### 1. Clarify before implementing

When the user's request is ambiguous, **ask before building**. Key questions:

- Which integration pattern? (smart contract only, backend only, hybrid)
- Mainnet or testnet?
- Does the app already have a Creator NFT and endorsement?

### 2. Implement with VeChain-specific correctness

- Network: always explicit (`mainnet`/`testnet`/`solo`)
- Use correct contract addresses for the target network
- Always include sustainability proofs when distributing rewards
- Register reward distributors before attempting distribution

### 3. Verify and deliver

A task is **not complete** until all applicable gates pass:

1. **Code compiles** — no build errors
2. **Tests pass** — existing tests still pass; new logic has test coverage
3. **Reward distribution tested** — verified on testnet with correct proofs

## Reference files

Read the matching files BEFORE doing anything else. See Critical Rules above.

| Topic | File | Read when user mentions... |
|-------|------|---------------------------|
| Getting started, integration patterns, test environment, contract addresses, reward distribution basics, fund management | [getting-started.md](references/getting-started.md) | building X2Earn app, getting started, testnet setup, solo node, reward distributor, integration pattern, fund management |
| Sustainability proofs, impact tracking, proof types, reward metadata | [sustainability-proofs.md](references/sustainability-proofs.md) | sustainability proof, impact codes, distributeRewardWithProof, proof types, impact categories, reward metadata |
| Security, anti-farming, bot prevention, rate limiting | [security.md](references/security.md) | security, farming, bot prevention, rate limiting, device fingerprinting, private key management, Guardian |
| AI image validation, photo verification, fake image detection | [ai-image-validation.md](references/ai-image-validation.md) | AI image validation, photo verification, fake image, doctored photo, watermark detection |
| App submission, Creator NFT, endorsement, APP_ID, categories | [app-submission.md](references/app-submission.md) | submit app, Creator NFT, endorsement, APP_ID, app categories, treasury address, admin address |
| VePassport, personhood check, bot signaling, Sybil resistance | [vepassport.md](references/vepassport.md) | VePassport, personhood, bot signaling, Sybil, isPerson, whitelisting, blacklisting, KYC |
