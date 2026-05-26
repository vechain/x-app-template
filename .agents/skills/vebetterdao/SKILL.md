---
name: vebetterdao
description: VeBetterDAO and X2Earn app development — B3TR/VOT3 tokens, reward distribution, sustainability proofs, app submission, governance, VeVote, quadratic funding, B3MO Quests, and navigators.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.2.0"
---

# VeBetterDAO Skill

## CRITICAL RULES

1. **Read reference files FIRST.** When the user's request involves any topic in the reference map below, read those files before doing anything else — before writing code, before making decisions. Briefly mention which files you are reading so the user can confirm the skill is active (e.g., "Reading VeBetterDAO reference...").
2. **Information priority for VeChain topics:** (a) Reference files in this skill — always the primary source. (b) VeChain MCP tools — use `@vechain/mcp-server` for on-chain data, transaction building, and live network queries; use Kapa AI MCP for VeChain documentation lookups. (c) Web search — only as a last resort, and only for topics NOT covered in the reference files.
3. **Prefer working directly in the main conversation** for VeChain tasks. Plan mode and subagents do not inherit skill context and may fall back to web search instead of using reference files.
4. **After compaction or context loss**, re-read this SKILL.md to restore awareness of the reference map and operating procedure before continuing work.

## Scope

Use this Skill for VeBetterDAO ecosystem development:

- X2Earn sustainability app development
- B3TR and VOT3 token integration
- Reward distribution (smart contract, hybrid, backend-only patterns)
- Sustainability proofs and impact codes
- App submission process to VeBetterDAO
- Governance: VeVote, proposals, voting, quadratic funding, allocation rounds
- Navigators: delegation, staking, freshness/intent multipliers, slashing
- B3MO Quests: quest creation, invitations, joining/leaving, claims, refunds, and indexer/frontend flows

## Operating procedure

### 1. Clarify before implementing

When the user's request is ambiguous, **ask before building**. Key questions:

- Which reward distribution pattern? (smart contract / hybrid / backend-only)
- Mainnet or testnet deployment?
- Does the app already have VeBetterDAO integration?

### 2. Implement with VeChain-specific correctness

- Network: always explicit (`mainnet`/`testnet`/`solo`)
- Tokens: B3TR for rewards, VOT3 for governance voting
- Use correct contract addresses for the target network

### 3. Verify and deliver

A task is **not complete** until all applicable gates pass:

1. **Code compiles** — no build errors
2. **Tests pass** — existing tests still pass; new logic has test coverage
3. **Risk notes documented** — any token-transfer or governance implications are called out

## Reference files

Read the matching files BEFORE doing anything else. See Critical Rules above.

- **VeBetterDAO**: [references/vebetterdao.md](references/vebetterdao.md) — read for X2Earn, B3TR, sustainability, rewards, VeBetterDAO, impact codes, app submission.
- **Governance**: [references/governance.md](references/governance.md) — read for VeVote, governance, voting, VOT3, proposal, steering committee, quadratic funding, allocation rounds.
- **B3MO Quests**: [references/b3mo-quests.md](references/b3mo-quests.md) — read for B3MO quests, quests, b3mo-quests, B3TRChallenges, SplitWin, MaxActions, quest invite, join quest, leave quest, claim prize, claim refund, quest indexer.
- **Contracts: tokens & apps**: [references/contracts-tokens-apps.md](references/contracts-tokens-apps.md) — read for B3TR, VOT3, Emissions, XAllocationVoting, XAllocationPool, X2EarnRewardsPool, X2EarnApps, X2EarnCreator, DBAPool, endorsement, reward distribution.
- **Contracts: governance & identity**: [references/contracts-governance-identity.md](references/contracts-governance-identity.md) — read for B3TRGovernor, proposals, VoterRewards, GalaxyMember, Treasury, TimeLock, RelayerRewardsPool, GrantsManager, B3TRMultiSig, VeBetterPassport, signaling, entity linking, upgradeability.
- **Navigators**: [references/navigators.md](references/navigators.md) — navigator, navigators, delegation, staking, slashing, NavigatorRegistry, freshness multiplier, governance intent multiplier, navigator fee, citizen voting.
