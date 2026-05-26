---
name: frontend
description: Generic frontend development patterns for VeChain dApps — React Query, Turborepo architecture, state management, Chakra UI, i18n, loading states, and transaction UX.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.1.0"
---

# Frontend Skill

## CRITICAL RULES

1. **Read reference files FIRST.** When the user's request involves any topic in the reference table below, read those files before doing anything else — before writing code, before making decisions. Briefly mention which files you are reading so the user can confirm the skill is active (e.g., "Reading frontend patterns reference...").
2. **Information priority for VeChain topics:** (a) Reference files in this skill — always the primary source. (b) VeChain MCP tools — use `@vechain/mcp-server` for on-chain data, transaction building, and live network queries; use Kapa AI MCP for VeChain documentation lookups. (c) Web search — only as a last resort, and only for topics NOT covered in the reference files.
3. **Prefer working directly in the main conversation** for VeChain tasks. Plan mode and subagents do not inherit skill context and may fall back to web search instead of using reference files.
4. **After compaction or context loss**, re-read this SKILL.md to restore awareness of the reference table and operating procedure before continuing work.

## Scope

Use this Skill for generic frontend development patterns in VeChain dApps:

- React Query (TanStack Query): query keys, cache invalidation, batch queries, loading states, anti-patterns
- Turborepo monorepo architecture and conventions
- State management (React Query for server state, Zustand for client state)
- Chakra UI integration and responsive design
- i18n with react-i18next
- Transaction UX: loading states, confirmation patterns, error handling
- Choosing between VeChain Kit and dapp-kit

For package-specific APIs (hooks, components, setup), see the **vechain-kit** skill.
For core VeChain SDK, fee delegation, and multi-clause transactions, see the **vechain-core** skill.

## Default stack

| Layer | Default | Alternative |
|-------|---------|-------------|
| Frontend | React / Next.js (App Router) | -- |
| Data fetching | `@tanstack/react-query` | -- |
| State management | Zustand (client state only) | -- |
| UI | Chakra UI v2 | -- |
| Monorepo | Turborepo | -- |
| Node | Node 20 LTS (managed via `nvm`) | -- |

## Operating procedure

### 1. Check Node version

Before installing dependencies or running any command:

- Check if `.nvmrc` exists in the project root. If yes, run `nvm use`.
- If `.nvmrc` does not exist, create one with `20` (Node 20 LTS) and run `nvm use`.

### 2. Detect project structure

- `turbo.json` present → follow Turborepo conventions (`apps/frontend`, `packages/*`)
- Apply conditional patterns (Chakra UI, i18n, Zustand) only when the project uses them

### 3. Clarify before implementing

When the user's request is ambiguous or could be solved multiple ways, **ask before building**. Separate research from implementation.

### 4. Implement with correctness

- Use React Query for all server state (contract reads, indexer data)
- Never duplicate server state in Zustand — let React Query be the source of truth
- Always use `enabled` guards on queries with dynamic params
- Always show skeletons while loading — never render empty/zero states during loads
- Invalidate affected caches after transactions

### 5. Verify and deliver

A task is **not complete** until all applicable gates pass:

1. **Code compiles** — no build errors (`npm run build` or equivalent succeeds)
2. **Tests pass** — existing tests still pass; new logic has test coverage
3. **Risk notes documented** — any signing, fee, or token-transfer implications are called out

## Reference files

Read the matching files BEFORE doing anything else. See Critical Rules above.

| Topic | File | Read when user mentions... |
|-------|------|---------------------------|
| Frontend patterns | [references/frontend.md](references/frontend.md) | frontend, React Query, caching, query keys, loading, skeleton, Turborepo, Chakra, i18n, state management, transaction UX, VeChain Kit vs dapp-kit |
