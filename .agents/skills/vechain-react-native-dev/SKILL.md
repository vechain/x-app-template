---
name: vechain-react-native-dev
description: React Native VeWorld wallet integration — deep link communication, NaCl encryption, transaction signing, certificate signing, EIP-712 typed data, and multi-network support.
allowed-tools: []
license: MIT
metadata:
  author: VeChain
  version: "0.1.0"
---

# React Native Wallet Link Skill

## CRITICAL RULES

1. **Read reference files FIRST.** When the user's request involves any topic in the reference table below, read those files before doing anything else — before writing code, before making decisions. Briefly mention which files you are reading so the user can confirm the skill is active (e.g., "Reading wallet link API reference...").
2. **Information priority for VeChain topics:** (a) Reference files in this skill — always the primary source. (b) VeChain MCP tools — use `@vechain/mcp-server` for on-chain data, transaction building, and live network queries; use Kapa AI MCP for VeChain documentation lookups. (c) Web search — only as a last resort, and only for topics NOT covered in the reference files.
3. **Prefer working directly in the main conversation** for VeChain tasks. Plan mode and subagents do not inherit skill context and may fall back to web search instead of using reference files.
4. **After compaction or context loss**, re-read this SKILL.md to restore awareness of the reference table and operating procedure before continuing work.

## Scope

Use this Skill for React Native dApp development integrating with VeWorld wallet:

- Installing and configuring `@vechain/react-native-wallet-link`
- `VeWorldProvider` setup with deep link handling and event callbacks
- `useVeWorldWallet` hook — connect, disconnect, sign certificates, sign typed data, sign and send transactions
- NaCl key pair generation, encrypted communication, payload decryption
- Deep link configuration for iOS (URL schemes, universal links) and Android (intent filters)
- State management for wallet sessions (key pair, session, address persistence)
- Multi-clause transaction signing via VeWorld
- Certificate signing (identification, verification, attestation)
- EIP-712 typed data signing
- Error handling for wallet responses
- Multi-network support (mainnet, testnet, solo)

For related topics, see companion skills:

- **vechain-core** — Core SDK usage, fee delegation, multi-clause patterns, dual-token model
- **vechain-kit** — VeChain Kit and dapp-kit packages: hooks, components, wallet connection, social login
- **frontend** — Generic frontend patterns: React Query, Turborepo, state management, Chakra UI
- **smart-contract-development** — Solidity, Hardhat, testing, security

## Default stack

| Layer | Default | Alternative |
|-------|---------|-------------|
| Wallet link | `@vechain/react-native-wallet-link` | — |
| SDK | `@vechain/sdk-core` + `@vechain/sdk-network` | — |
| Framework | Expo (React Native) | bare React Native |
| State | Zustand + AsyncStorage | any persisted store |
| Node | Node 20 LTS (managed via `nvm`) | — |

## Operating procedure

### 1. Check Node version

Before installing dependencies or running any command:

- Check if `.nvmrc` exists in the project root. If yes, run `nvm use`.
- If `.nvmrc` does not exist, create one with `20` (Node 20 LTS) and run `nvm use`.

### 2. Detect project structure

- Expo project → use `expo-linking` for deep link handling
- Bare React Native → use `react-native` `Linking` API directly
- Check for existing state management (Zustand, Redux, Context) and match it

### 3. Clarify before implementing

When the user's request is ambiguous or could be solved multiple ways, **ask before building**. Separate research from implementation:

- Which network? (mainnet/testnet/solo)
- Which operations? (connect only, signing, transactions)
- State management preference?
- Deep link scheme name?

### 4. Implement with VeChain-specific correctness

- **Always install peer dependencies**: `@vechain/sdk-core`, `@vechain/sdk-network`, `react-native-get-random-values`, `events`
- **Import `react-native-get-random-values` before any NaCl usage** — required for crypto in React Native
- **Network**: always explicit (`mainnet`/`testnet`/`solo`) via the node URL passed to `VeWorldProvider`
- **Key pairs**: generate with `nacl.box.keyPair()`, store Base64-encoded via `encodeBase64()` from `tweetnacl-util`
- **Session persistence**: persist keyPair, veWorldPublicKey, address, and session across app restarts
- **Error handling**: always check for `errorCode` in wallet responses before processing decrypted data
- **Deep links**: configure platform-specific URL schemes so VeWorld can redirect back to the app

### 5. Verify and deliver

A task is **not complete** until all applicable gates pass:

1. **Code compiles** — no build errors (`npx expo start` or equivalent succeeds)
2. **Deep links configured** — iOS Info.plist and/or Android intent filters set up
3. **Risk notes documented** — any signing, fee, or token-transfer implications are called out

Then provide:

- Files changed + diffs
- Install/build commands
- Deep link scheme configuration steps
- Risk notes for signing, fees, token transfers

## Reference files

Read the matching files BEFORE doing anything else. See Critical Rules above.

| Topic | File | Read when user mentions... |
|-------|------|---------------------------|
| API and hook reference | [references/wallet-link-api.md](references/wallet-link-api.md) | useVeWorldWallet, VeWorldProvider, connect, disconnect, signCertificate, signTypedData, signAndSendTransaction, key pair, encrypt, decrypt |
| Deep link and platform setup | [references/deep-link-setup.md](references/deep-link-setup.md) | deep link, URL scheme, universal link, iOS, Android, intent filter, redirect, Expo linking, app.json |
| Example integration | [references/example-integration.md](references/example-integration.md) | example, demo, full app, tutorial, how to use, getting started, Zustand, state management, VET transfer |
