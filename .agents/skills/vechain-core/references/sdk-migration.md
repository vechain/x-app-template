# Connex / Thor DevKit -> SDK Migration

## When to use

Use when the user has Connex, thor-devkit, web3-providers-connex, or @vechain/hardhat-vechain in their project, or asks about migrating from deprecated VeChain packages.

## The rule
- New code: `@vechain/sdk-core` + `@vechain/sdk-network` types and APIs.
- Legacy dependencies: isolate Connex/Thor DevKit usage behind an adapter boundary.

## Background
As of December 31, 2024, VeChain deprecated all legacy developer tools in favor of the unified SDK:

| Deprecated Package | Replacement |
|-------------------|-------------|
| `@vechain/connex` | `@vechain/sdk-network` (ThorClient) |
| `thor-devkit` | `@vechain/sdk-core` |
| `@vechain/hardhat-vechain` | `@vechain/sdk-hardhat-plugin` |
| `web3-providers-connex` | `@vechain/sdk-ethers-adapter` |

## Preferred migration: direct SDK usage

Use `@vechain/sdk-core` and `@vechain/sdk-network` directly:

### Transaction building (was thor-devkit)

```typescript
// OLD (thor-devkit)
import { Transaction, secp256k1 } from 'thor-devkit';
const tx = new Transaction({ chainTag: 0x27, ... });

// NEW (@vechain/sdk-core)
import { Transaction, Clause, Address, VET } from '@vechain/sdk-core';
const clauses = [Clause.transferVET(Address.of('0x...'), VET.of(100))];
const signedTx = Transaction.of({ chainTag: 0x27, clauses, ... }).sign(privateKey);
```

### Network interaction (was Connex)

```typescript
// OLD (Connex)
const connex = new Connex({ node: 'https://testnet.vechain.org', network: 'test' });
const account = await connex.thor.account('0x...').get();

// NEW (@vechain/sdk-network)
import { ThorClient } from '@vechain/sdk-network';
const thorClient = ThorClient.at('https://testnet.vechain.org');
const account = await thorClient.accounts.getAccount('0x...');
```

### Contract interaction (was Connex.Thor)

```typescript
// OLD (Connex)
const method = connex.thor.account(contractAddr).method(abiItem);
const result = await method.call(arg1, arg2);

// NEW (@vechain/sdk-network)
const contract = thorClient.contracts.load(contractAddr, abi);
const result = await contract.read.methodName(arg1, arg2);
```

### Signing transactions (was Connex.Vendor)

```typescript
// OLD (Connex)
const result = await connex.vendor.sign('tx', [clause]).request();

// NEW (with dapp-kit v2 - for frontend)
import { useThor } from '@vechain/dapp-kit-react';
const thor = useThor();
// Use thor for contract reads; use useSendTransaction for writes

// NEW (with SDK - for backend/scripts)
const signedTx = Transaction.of(body).sign(privateKey);
const result = await thorClient.transactions.sendRawTransaction(
  HexUInt.of(signedTx.encoded).toString()
);
```

## Practical boundary layout (when legacy code exists)
Keep these modules separate:

- `src/vechain/sdk/`:
  - all SDK-first code: ThorClient, Clause builders, contract interaction, typed transactions

- `src/vechain/legacy/`:
  - adapters for legacy Connex-based libraries
  - conversions between Connex types and SDK types
  - only at edges where migration is not yet complete

## ethers.js adapter

For projects using ethers.js patterns, use `@vechain/sdk-ethers-adapter`:

```typescript
import { VeChainProvider } from '@vechain/sdk-ethers-adapter';

// Creates an ethers-compatible provider backed by VeChainThor
const provider = new VeChainProvider(thorClient);
```

## Common mistakes to prevent
- Using `useConnex` anywhere (deprecated in both VeChain Kit and dapp-kit v2; use `useThor` instead)
- Mixing Connex `thor` and SDK `ThorClient` in the same module (causes confusion)
- Using deprecated `thor-devkit` for new transaction construction (use `@vechain/sdk-core`)
- Importing `web3-providers-connex` when `@vechain/sdk-ethers-adapter` exists
- Not updating Hardhat plugin (old `@vechain/hardhat-vechain` vs new `@vechain/sdk-hardhat-plugin`)

## Decision checklist
If you're about to add a legacy VeChain dependency:
1) Is there an SDK-native equivalent? Prefer SDK.
2) Is the only reason a legacy library? Isolate it at the boundary.
3) Can you use `@vechain/sdk-ethers-adapter` instead of `web3-providers-connex`? Prefer the adapter.
