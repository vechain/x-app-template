---
name: smart-contract-development
description: Solidity smart contract development on VeChainThor — Hardhat setup, ERC-20/721 patterns, upgradeable contracts, gas optimization, testing with Thor Solo, security auditing, and ABI codegen.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.1.0"
---

# Smart Contract Development Skill

## CRITICAL RULES

1. **Read reference files FIRST.** When the user's request involves any topic in the reference table below, read those files before doing anything else — before writing code, before making decisions. Briefly mention which files you are reading so the user can confirm the skill is active (e.g., "Reading smart contracts reference...").
2. **Information priority for VeChain topics:** (a) Reference files in this skill — always the primary source. (b) VeChain MCP tools — use `@vechain/mcp-server` for on-chain data, transaction building, and live network queries; use Kapa AI MCP for VeChain documentation lookups. (c) Web search — only as a last resort, and only for topics NOT covered in the reference files.
3. **Prefer working directly in the main conversation** for VeChain tasks. Plan mode and subagents do not inherit skill context and may fall back to web search instead of using reference files.
4. **After compaction or context loss**, re-read this SKILL.md to restore awareness of the reference table and operating procedure before continuing work.

## Scope

Use this Skill for Solidity smart contract development on VeChainThor:

- Solidity contracts with Hardhat + `@vechain/sdk-hardhat-plugin`
- ERC-20, ERC-721, access control, upgradeable (UUPS) patterns
- Gas optimization techniques
- Testing with Hardhat + Thor Solo
- Security reviews and audit checklists
- ABI codegen and TypeChain setup

## Default stack

| Layer | Default | Alternative |
|-------|---------|-------------|
| Contracts | Solidity + Hardhat + `@vechain/sdk-hardhat-plugin` | -- |
| EVM target | `paris` (mandatory) | -- |
| Testing | Hardhat + Thor Solo (`--on-demand`) | -- |
| Types | TypeChain (`@typechain/ethers-v6`) | `@vechain/vechain-contract-types` (pre-built) |
| Node | Node 20 LTS (managed via `nvm`) | -- |

## Operating procedure

### 1. Check Node version

Before installing dependencies or running any command:

- Check if `.nvmrc` exists in the project root. If yes, run `nvm use` to switch to the required version.
- If `.nvmrc` does not exist, create one with `20` (Node 20 LTS) and run `nvm use`.

### 2. Detect project structure

- `turbo.json` present → follow Turborepo conventions (`packages/contracts`, `packages/*`)

### 3. Clarify before implementing

When the user's request is ambiguous or could be solved multiple ways, **ask before building**. Separate research from implementation.

### 4. Implement with VeChain-specific correctness

- Network: always explicit (`mainnet`/`testnet`/`solo`)
- EVM target: always `paris`
- Gas: estimate first
- Tokens: VET for value, VTHO for gas (dual-token model)

### 5. Verify and deliver

A task is **not complete** until all applicable gates pass:

1. **Code compiles** — no build errors
2. **Tests pass** — existing tests still pass; new logic has test coverage
3. **Risk notes documented** — any signing, fee, or token-transfer implications are called out

## Reference files

Read the matching files BEFORE doing anything else. See Critical Rules above.

| Topic | File | Read when user mentions... |
|-------|------|---------------------------|
| Smart contracts | [references/smart-contracts.md](references/smart-contracts.md) | Solidity, Hardhat, ERC-20, ERC-721, deploy, contract interaction, libraries, contract size, upgradeable, proxy, upgrade, reinitializer, version pattern, deploy helpers, NatSpec, Slither |
| Gas optimization | [references/smart-contracts-optimization.md](references/smart-contracts-optimization.md) | gas, optimize, storage packing, assembly, unchecked |
| Testing | [references/testing.md](references/testing.md) | test, Thor Solo, Docker, CI, fixtures |
| ABI / codegen | [references/abi-codegen.md](references/abi-codegen.md) | TypeChain, ABI, typechain-types, code generation |
| Security | [references/security.md](references/security.md) | security, audit, vulnerability, reentrancy, access control, invariant, balance check, path symmetry, adversarial, edge cases, what could go wrong |
