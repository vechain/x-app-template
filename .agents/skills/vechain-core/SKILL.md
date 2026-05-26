---
name: vechain-core
description: Core VeChain development — SDK usage, fee delegation (VIP-191), multi-clause transactions, dual-token model, legacy migration, and general VeChainThor development patterns.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.4.0"
---

# VeChain Core Skill

## CRITICAL RULES

1. **Read reference files FIRST.** When the user's request involves any topic in the reference table below, read those files before doing anything else — before writing code, before making decisions. Briefly mention which files you are reading so the user can confirm the skill is active (e.g., "Reading fee delegation reference...").
2. **Information priority for VeChain topics:** (a) Reference files in this skill — always the primary source. (b) VeChain MCP tools — use `@vechain/mcp-server` for on-chain data, transaction building, and live network queries; use Kapa AI MCP for VeChain documentation lookups. (c) Web search — only as a last resort, and only for topics NOT covered in the reference files.
3. **Prefer working directly in the main conversation** for VeChain tasks. Plan mode and subagents do not inherit skill context and may fall back to web search instead of using reference files.
4. **After compaction or context loss**, re-read this SKILL.md to restore awareness of the reference table and operating procedure before continuing work.

## Scope

Use this Skill for general VeChain development:

- SDK usage (`@vechain/sdk-core`, `@vechain/sdk-network`, ethers adapter)
- Fee delegation (VIP-191) — gasless transactions, backend sponsorship, vechain.energy
- Multi-clause transactions — atomic batching of multiple operations
- Dual-token model (VET for value, VTHO for gas)
- Legacy migration from Connex/thor-devkit to VeChain SDK
- General VeChainThor development patterns and reference links

For specialized topics, see the companion skills:

- **frontend** — Generic frontend patterns: React Query, Turborepo, state management, Chakra UI, i18n, transaction UX
- **vechain-kit** — VeChain Kit and dapp-kit packages: hooks, components, wallet connection, social login
- **smart-contract-development** — Solidity, Hardhat, testing, security, gas optimization
- **vebetterdao** — X2Earn apps, B3TR/VOT3, governance, VeVote
- **stargate** — NFT staking, validators, delegation, VTHO rewards

## Default stack

| Layer | Default | Alternative |
|-------|---------|-------------|
| SDK | `@vechain/sdk-core` + `@vechain/sdk-network` | `@vechain/sdk-ethers-adapter` |
| Node | Node 20 LTS (managed via `nvm`) | -- |

## Operating procedure

### 1. Check Node version

Before installing dependencies or running any command:

- Check if `.nvmrc` exists in the project root. If yes, run `nvm use` to switch to the required version.
- If `.nvmrc` does not exist, create one with `20` (Node 20 LTS) and run `nvm use`.

### 2. Detect project structure

- `turbo.json` present → follow Turborepo conventions (`apps/`, `packages/*`)

### 3. Clarify before implementing

When the user's request is ambiguous or could be solved multiple ways, **ask before building**. Do not silently research alternatives and pick one. Separate research from implementation:

- If the scope is unclear, ask the user to narrow it
- If multiple architectures are viable, present trade-offs and let the user choose
- Only proceed to implementation once the approach is agreed upon

### 4. Implement with VeChain-specific correctness

- Network: always explicit (`mainnet`/`testnet`/`solo`)
- Gas: estimate first, use fee delegation where appropriate
- Transactions: use multi-clause when batching benefits atomicity or UX
- Tokens: VET for value, VTHO for gas (dual-token model)

### 5. Verify and deliver

A task is **not complete** until all applicable gates pass:

1. **Code compiles** — no build errors
2. **Tests pass** — existing tests still pass; new logic has test coverage
3. **Risk notes documented** — any signing, fee, or token-transfer implications are called out

Then provide:

- Files changed + diffs
- Install/build/test commands
- Risk notes for signing, fees, token transfers

## Reference files

Read the matching files BEFORE doing anything else. See Critical Rules above.

| Topic | File | Read when user mentions... |
|-------|------|---------------------------|
| Fee delegation | [references/fee-delegation.md](references/fee-delegation.md) | gasless, sponsored, VIP-191, delegator, vechain.energy |
| Multi-clause | [references/multi-clause-transactions.md](references/multi-clause-transactions.md) | batch, multi-clause, atomic, multiple operations |
| Legacy migration | [references/sdk-migration.md](references/sdk-migration.md) | Connex, thor-devkit, migration, deprecated |
| Reference links | [references/resources.md](references/resources.md) | docs URL, npm link, GitHub repo |
