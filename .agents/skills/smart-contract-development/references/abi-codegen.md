# ABIs + Client Generation (TypeChain)

## When to use

Use when the user asks about TypeChain, type-safe contract interaction, ABI extraction, code generation, or `@vechain/vechain-contract-types`.

## Rule

Never hand-maintain contract interaction code. Use ABI-driven, code-generated workflow.

## Hardhat + TypeChain Setup

```bash
npm install --save-dev @typechain/hardhat typechain @typechain/ethers-v6
```

```typescript
// hardhat.config.ts
import '@typechain/hardhat';

const config = {
  typechain: {
    outDir: 'typechain-types',
    target: 'ethers-v6',
  },
};
```

```bash
# Types generated automatically on compile
npx hardhat compile
# Output: typechain-types/
```

## Using Generated Types

```typescript
import { MyToken, MyToken__factory } from '../typechain-types';

// Deploy
const factory = new MyToken__factory(signer);
const token: MyToken = await factory.deploy(1_000_000);

// Read/write with full type safety
const balance: bigint = await token.balanceOf(address);
await token.transfer(recipient, amount);

// Typed event filters
const filter = token.filters.Transfer(from, to);
const events = await token.queryFilter(filter);
```

## Using Types with VeChain Kit (useCallClause)

```typescript
import { useCallClause } from '@vechain/vechain-kit';
import { MyContract__factory } from '../typechain-types';

export const useTokenBalance = (address: string) => {
  return useCallClause({
    abi: MyContract__factory.abi,
    address: CONTRACT_ADDRESS,
    method: 'balanceOf',
    args: [address],
    queryOptions: { enabled: !!address },
  });
};
```

## Pre-built Types: @vechain/vechain-contract-types

**Always install this package** when building VeChain dApps. It provides TypeChain-generated ABIs and factories for all major VeChain ecosystem contracts — no need to hand-write ABIs.

```bash
npm install @vechain/vechain-contract-types
```

### Available contract categories

| Category | Key factories | Use for |
|----------|--------------|---------|
| **Built-in / B32** | `Energy__factory`, `Params__factory`, `Authority__factory`, `Extension__factory`, `Prototype__factory` | VeChainThor built-in contracts (VTHO, chain params) |
| **Smart accounts** | `SocialLoginSmartAccount__factory`, `SocialLoginSmartAccountFactory__factory` | Social login account abstraction |
| **VeBetterDAO** | `B3TR__factory`, `VOT3__factory`, `X2EarnApps__factory`, `X2EarnRewardsPool__factory`, `XAllocationVoting__factory`, `VeBetterPassport__factory`, `GalaxyMember__factory`, `Emissions__factory`, `Treasury__factory`, `VoterRewards__factory` | X2Earn apps, governance, rewards |
| **StarGate** | `Stargate__factory`, `StargateNFT__factory`, `IProtocolStaker__factory` | VET staking, node management |
| **VeVote** | `VeVote__factory` | Governance proposals and voting |
| **VET domains** | `VetDomainsRegistry__factory`, `VetDomainsPublicResolver__factory`, `VetDomainsResolveUtilities__factory` | .vet domain resolution |
| **DEX** | `UniswapV2Factory__factory`, `UniswapV2Pair__factory`, `UniswapV2Router02__factory` | DEX interactions |
| **Tokens** | `Vip180Mintable__factory`, `Vip181Mintable_v7__factory` | Standard VIP-180/VIP-181 tokens |

### Usage with useCallClause

```typescript
import { useCallClause } from '@vechain/vechain-kit';
import { B3TR__factory } from '@vechain/vechain-contract-types';

export const useB3trBalance = (address: string) => {
  return useCallClause({
    abi: B3TR__factory.abi,
    address: B3TR_CONTRACT_ADDRESS,
    method: 'balanceOf',
    args: [address],
    queryOptions: { enabled: !!address },
  });
};
```

### Usage with ThorClient

```typescript
import { B3TR__factory } from '@vechain/vechain-contract-types';

const contract = thorClient.contracts.load(contractAddress, B3TR__factory.abi);
```

Do not modify auto-generated files in this package.

## ABI Extraction

Hardhat produces ABI artifacts in `artifacts/contracts/`:

```typescript
import MyTokenArtifact from '../artifacts/contracts/MyToken.sol/MyToken.json';
const abi = MyTokenArtifact.abi;
const bytecode = MyTokenArtifact.bytecode;
```

For SDK contract interaction patterns using raw ABIs, see [smart-contracts.md](smart-contracts.md).

## Guardrails

- TypeChain output should be in `.gitignore` (generated on compile)
- If consumers need pre-built types, publish the package or check in generated files
- Always regenerate after contract changes (`npx hardhat compile`)
- Do NOT copy-paste ABI arrays into application code manually
- Do NOT write manual TypeScript interfaces for contract methods
- Do NOT use `any` types when TypeChain is available
