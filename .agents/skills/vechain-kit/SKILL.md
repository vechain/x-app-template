---
name: vechain-kit
description: VeChain Kit and dapp-kit packages — installation, hooks, components, wallet connection, social login, smart accounts, theming, and Privy setup.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.1.0"
---

# VeChain Kit Skill

## CRITICAL RULES

1. **Read reference files FIRST.** When the user's request involves any topic in the reference table below, read those files before doing anything else — before writing code, before making decisions. Briefly mention which files you are reading so the user can confirm the skill is active (e.g., "Reading VeChain Kit reference...").
2. **Information priority for VeChain topics:** (a) Reference files in this skill — always the primary source. (b) VeChain MCP tools — use `@vechain/mcp-server` for on-chain data, transaction building, and live network queries; use Kapa AI MCP for VeChain documentation lookups. (c) Web search — only as a last resort, and only for topics NOT covered in the reference files.
3. **Prefer working directly in the main conversation** for VeChain tasks. Plan mode and subagents do not inherit skill context and may fall back to web search instead of using reference files.
4. **After compaction or context loss**, re-read this SKILL.md to restore awareness of the reference table and operating procedure before continuing work.

## Scope

Use this Skill for the VeChain Kit and dapp-kit packages specifically:

- VeChain Kit: installation, setup, configuration, Privy integration
- dapp-kit: lightweight wallet connection for non-React or minimal setups
- Wallet connection, social login (email, Google, passkey), smart accounts
- Pre-built UI components (WalletButton, TransactionModal)
- Hooks (useWallet, useSendTransaction, useCallClause, token/domain/oracle hooks)
- Theming and Privy setup
- i18n with react-i18next: bi-directional language sync (Kit ↔ host app), pre-commit/ESLint for missing or unused translation keys

For generic frontend patterns (React Query, Turborepo, state management, Chakra UI, transaction UX), see the **frontend** skill.

## Default stack

| Layer | Default | Alternative |
|-------|---------|-------------|
| Frontend | `@vechain/vechain-kit` | `@vechain/dapp-kit-react` (lightweight/non-React) |
| Node | Node 20 LTS (managed via `nvm`) | -- |

## Operating procedure

### 1. Check Node version

Before installing dependencies or running any command:

- Check if `.nvmrc` exists in the project root. If yes, run `nvm use`.
- If `.nvmrc` does not exist, create one with `20` (Node 20 LTS) and run `nvm use`.

### 2. Detect project structure

- `turbo.json` present → follow Turborepo conventions (`apps/frontend`, `packages/*`)
- Use `useThor` for Thor client access (both VeChain Kit and dapp-kit v2). `useConnex` is deprecated everywhere.
- Apply conditional patterns (Chakra UI, i18n, Zustand) only when the project uses them

### 3. Choose the right library

**When to ask the user:** If the project doesn't already use VeChain Kit or dapp-kit and the user hasn't specified which to use, ask before choosing. Key questions:

- Do you need social login (email, Google, passkey)? → VeChain Kit
- Do you want pre-built UI modals and hooks (WalletButton, TransactionModal, token hooks)? → VeChain Kit
- Do you want a lightweight wallet-only integration with minimal dependencies? → dapp-kit
- Non-React framework? → dapp-kit

### 4. Clarify before implementing

When the user's request is ambiguous or could be solved multiple ways, **ask before building**. Separate research from implementation.

### 5. Implement with VeChain-specific correctness

- Network: always explicit (`mainnet`/`testnet`/`solo`)
- Social login: Generic Delegator auto-enabled (users pay gas in VET/VTHO/B3TR); app-sponsored delegation optional for better UX; smart accounts; pre-fetch data before `sendTransaction`

### 6. Verify and deliver

A task is **not complete** until all applicable gates pass:

1. **Code compiles** — no build errors (`npm run build` or equivalent succeeds)
2. **Tests pass** — existing tests still pass; new logic has test coverage
3. **Risk notes documented** — any signing, fee, or token-transfer implications are called out

## Reference files

Read the matching files BEFORE doing anything else. See Critical Rules above.

| Topic | File | Read when user mentions... |
|-------|------|---------------------------|
| Setup & config | [references/kit-setup.md](references/kit-setup.md) | Installing VeChain Kit, provider setup, CSS framework, Tailwind, env vars, login methods, legal documents, ecosystem apps, common pitfalls |
| Hooks | [references/kit-hooks.md](references/kit-hooks.md) | useWallet, useCallClause, useSendTransaction, useBuildTransaction, useSignMessage, contract reads, transactions, VET domains, NFTs, blockchain hooks, language/currency, @vechain/contract-getters |
| Components & modals | [references/kit-components.md](references/kit-components.md) | WalletButton, TransactionModal, TransactionToast, modal hooks, isolated views |
| Social login | [references/kit-social-login.md](references/kit-social-login.md) | Social login, smart accounts, account abstraction, Privy setup, fee delegation for social login, DIY social login |
| Theming | [references/kit-theming.md](references/kit-theming.md) | Theming, colors, fonts, buttons, glass effects, bottom sheet, Chakra UI compatibility, webpack fallbacks |
| dapp-kit | [references/frontend-dappkit.md](references/frontend-dappkit.md) | dapp-kit, DAppKitProvider, lightweight wallet |
| Translations + Kit | [references/translations-vechain-kit.md](references/translations-vechain-kit.md) | i18n, translations, language sync, VeChain Kit language, missing translations, pre-commit, ESLint, unused keys |
