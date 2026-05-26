# Curated Resources (Source-of-Truth First)

## MCP Server (Live AI-Powered Docs + Blockchain Data)

The VeChain MCP server gives Claude Code direct access to VeChain documentation search, blockchain queries, token data, VeBetterDAO stats, and StarGate staking info -- all without leaving the editor.

### Setup (Claude Code)

Add to `~/.claude/mcp.json`:
```json
{
  "mcpServers": {
    "vechain": {
      "command": "npx",
      "args": ["-y", "@vechain/mcp-server@latest"],
      "env": {
        "VECHAIN_NETWORK": "mainnet"
      }
    }
  }
}
```

Set `VECHAIN_NETWORK` to `mainnet`, `testnet`, or `solo`. Restart Claude Code after adding.

### Available Tools (26)

| Category | Tools |
|----------|-------|
| **Docs search** | `searchDocsVechain`, `searchDocsVechainKit`, `searchDocsVebetterDao`, `searchDocsVevote`, `searchDocsStargate` |
| **Blockchain** | `thorGetBlock`, `thorGetTransaction`, `thorGetAccount`, `thorDecodeEvent` |
| **Tokens/NFTs** | `getTokenBalances`, `getTokenFiatPrice`, `getTokenRegistry`, `getNFTs`, `getNFTContracts` |
| **VeBetterDAO** | `getB3TRGlobalOverview`, `getB3TRAppsLeaderboard`, `getB3TRProposalsResults`, `getB3TRProposalComments`, `getCurrentRound`, `getGMNFTStatus` |
| **Staking** | `getStargateTotalVetStaked`, `getStargateTokenRewards`, `getValidators` |
| **History** | `getTransactions`, `getTransfersOfAccount`, `getHistoryOfAccount` |

- [@vechain/mcp-server npm](https://www.npmjs.com/package/@vechain/mcp-server)
- [VeChain MCP Server GitHub](https://github.com/vechain/vechain-mcp-server)

### Kapa.ai Docs MCP (alternative, docs-only)

For docs-only queries via Kapa.ai's hosted infrastructure:
```bash
claude mcp add --transport http vechain-docs https://vechain.mcp.kapa.ai
```

---

## Core VeChain Documentation
- [VeChain Documentation](https://docs.vechain.org/) (Core concepts, SDKs, tutorials)
- [VeChain Whitepaper](https://www.vechain.org/whitepaper/)
- [VeChainThor Transaction Model](https://docs.vechain.org/core-concepts/transactions/transaction-model)
- [Dual-Token Economic Model](https://docs.vechain.org/introduction-to-vechain/dual-token-economic-model)

## VeChain Kit (preferred for React/Next.js dApps)
- [VeChain Kit Documentation](https://docs.vechainkit.vechain.org/)
- [Should I Use It?](https://docs.vechainkit.vechain.org/discover-vechain-kit/should-i-use-it) (decision framework)
- [Installation](https://docs.vechainkit.vechain.org/quickstart/installation)
- [Provider Configuration](https://docs.vechainkit.vechain.org/quickstart/provider-configuration)
- [Send Transactions](https://docs.vechainkit.vechain.org/quickstart/send-transactions)
- [Hooks Reference](https://docs.vechainkit.vechain.org/hooks)
- [Components Reference](https://docs.vechainkit.vechain.org/components)
- [Social Login / Privy Setup](https://docs.vechainkit.vechain.org/quickstart/setup-privy-optional)
- [Smart Accounts](https://docs.vechainkit.vechain.org/social-login/smart-accounts)
- [Fee Delegation Setup](https://docs.vechainkit.vechain.org/fee-delegation/fee-delegation-setup)
- [Theming](https://docs.vechainkit.vechain.org/customization/theming)
- [@vechain/vechain-kit npm](https://www.npmjs.com/package/@vechain/vechain-kit)

### VeChain Kit Docs MCP Server

The VeChain Kit documentation site exposes a GitBook-powered MCP server for AI tools. It provides read-only search and retrieval of the latest published docs — useful for looking up hooks, components, configuration, and social login details directly from your AI editor.

**Endpoint:** `https://docs.vechainkit.vechain.org/~gitbook/mcp`

**Transport:** HTTP only (no stdio or SSE).

**Claude Code setup:**
```bash
claude mcp add --transport http vechain-kit-docs https://docs.vechainkit.vechain.org/~gitbook/mcp
```

**Cursor / VS Code (`mcp.json`):**
```json
{
  "servers": {
    "vechain-kit-docs": {
      "url": "https://docs.vechainkit.vechain.org/~gitbook/mcp"
    }
  }
}
```

This complements the `@vechain/mcp-server` (which provides blockchain data + multi-site docs search) with direct, always-up-to-date access to the VeChain Kit documentation specifically.

## Smart Accounts (Account Abstraction)
- [Smart Accounts GitHub](https://github.com/vechain/smart-accounts) (official SimpleAccount + SimpleAccountFactory)
- [Smart Accounts Documentation](https://docs.vechainkit.vechain.org/social-login/smart-accounts)
- [DIY Social Login Tutorial (dapp-kit + Privy)](https://docs.vechain.org/developer-resources/example-dapps/pwa-with-privy-and-account-abstraction) (complex, VeChain Kit recommended instead)
- [DIY Tutorial Example Repo](https://github.com/vechain-energy/docs-pwa-privy-account-abstraction-my-pwa-project)

## Scaffolding
- [create-vechain-dapp](https://www.npmjs.com/package/create-vechain-dapp) (`npx create-vechain-dapp@latest`)
- [create-vechain-dapp GitHub](https://github.com/vechain/create-vechain-dapp) (templates: X2Earn, Simple Dapp, Buy Me Coffee, Smart Contract)

## VeChain SDK
- [VeChain SDK GitHub](https://github.com/vechain/vechain-sdk-js)
- [@vechain/sdk-core npm](https://www.npmjs.com/package/@vechain/sdk-core) (offline: transactions, signing, encoding)
- [@vechain/sdk-network npm](https://www.npmjs.com/package/@vechain/sdk-network) (network: ThorClient, providers, contracts)
- [@vechain/sdk-errors npm](https://www.npmjs.com/package/@vechain/sdk-errors)
- [@vechain/vechain-contract-types npm](https://www.npmjs.com/package/@vechain/vechain-contract-types) (pre-built TypeChain types for VeChain ecosystem contracts)
- [@vechain/contract-getters npm](https://www.npmjs.com/package/@vechain/contract-getters) (framework-agnostic read-only getters: balances, VNS, avatars, smart accounts)
- [SDK Accounts Guide](https://docs.vechain.org/developer-resources/sdks-and-providers/sdk/accounts)
- [SDK Transactions Guide](https://docs.vechain.org/developer-resources/sdks-and-providers/sdk/transactions)
- [SDK Contracts Guide](https://docs.vechain.org/developer-resources/sdks-and-providers/sdk/contracts)
- [SDK ThorClient Guide](https://docs.vechain.org/developer-resources/sdks-and-providers/sdk/thor-client)

## DApp Kit (lightweight alternative)
- [DApp Kit Documentation](https://docs.vechain.org/developer-resources/sdks-and-providers/dapp-kit)
- [@vechain/dapp-kit-react npm](https://www.npmjs.com/package/@vechain/dapp-kit-react)
- [DApp Kit React Usage](https://docs.vechain.org/developer-resources/sdks-and-providers/dapp-kit/dapp-kit-1/react/usage)

## Wallets
- [VeWorld Wallet](https://www.veworld.net/) (official wallet -- browser extension + mobile)
- [VeWorld Documentation](https://docs.vechain.org/core-concepts/wallets/veworld)

## Smart Contract Development

### Hardhat Integration
- [Build with Hardhat Guide](https://docs.vechain.org/developer-resources/how-to-build-on-vechain/build-with-hardhat)
- [Hardhat Plugin Documentation](https://docs.vechain.org/developer-resources/frameworks-and-ides/hardhat)
- [@vechain/sdk-hardhat-plugin npm](https://www.npmjs.com/package/@vechain/sdk-hardhat-plugin)

### OpenZeppelin
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/)
- [OpenZeppelin Wizard](https://wizard.openzeppelin.com/) (contract generator)

### Solidity
- [Solidity Documentation](https://docs.soliditylang.org/)
- [Solidity by Example](https://solidity-by-example.org/)

## Local Development
- [Thor Solo Node Guide](https://docs.vechain.org/how-to-run-a-node/how-to-run-a-thor-solo-node)
- [Thor Node GitHub](https://github.com/vechain/thor)
- [Docker Hub: vechain/thor](https://hub.docker.com/r/vechain/thor)

## VeChain-Specific Features

### Fee Delegation
- [Fee Delegation Overview](https://docs.vechain.org/core-concepts/transactions/meta-transaction-features/fee-delegation)
- [VIP-191 Integration Guide](https://docs.vechain.org/developer-resources/vip-191-designated-gas-payer/how-to-integrate-vip-191-i)
- [vechain.energy Managed Delegation](https://vechain.energy/)

### Multi-Clause Transactions
- [Multi-Clause Documentation](https://docs.vechain.org/core-concepts/transactions/meta-transaction-features/clauses-multi-task-transaction)

### Token Standards
- [VIP-180 (Fungible Token)](https://github.com/vechain/VIPs/blob/master/vips/VIP-180.md) (ERC-20 compatible, superseded by standard ERC-20)
- [VIP-181 (Non-Fungible Token)](https://github.com/vechain/VIPs/blob/master/vips/VIP-181.md) (ERC-721 compatible, superseded by standard ERC-721)

### VET Domains
- [VET Domains](https://vet.domains/) (.vet domain name service)

## Ethers.js Compatibility
- [@vechain/sdk-ethers-adapter npm](https://www.npmjs.com/package/@vechain/sdk-ethers-adapter)
- [ethers.js Documentation](https://docs.ethers.org/)

## Testing
- [Hardhat Testing Guide](https://hardhat.org/tutorial/testing-contracts)
- [Chai Matchers (Hardhat)](https://hardhat.org/hardhat-chai-matchers/docs/overview)

## Security
- [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/security)
- [SWC Registry](https://swcregistry.io/) (Smart Contract Weakness Classification)
- [Slither (Static Analyzer)](https://github.com/crytic/slither)

## VeBetterDAO (X2Earn Sustainability Apps)
- [VeBetterDAO Documentation](https://docs.vebetterdao.org/)
- [Developer Guide: Get Started](https://docs.vebetterdao.org/developer-guides/get-started)
- [Reward Distribution](https://docs.vebetterdao.org/developer-guides/reward-distribution)
- [Sustainability Proofs & Impacts](https://docs.vebetterdao.org/developer-guides/sustainability-proof-and-impacts)
- [Submit Your App](https://docs.vebetterdao.org/developer-guides/submit-your-app)
- [Test Environment](https://docs.vebetterdao.org/developer-guides/test-environment)
- [X-App-Template (GitHub)](https://github.com/vechain/x-app-template)
- [VeBetterDAO Contracts (GitHub)](https://github.com/vechain/vebetterdao-contracts)
- [Smart Contract Addresses](https://docs.vebetterdao.org/smart-contracts)

## StarGate (NFT-Based Staking)
- [StarGate Documentation](https://docs.stargate.vechain.org/)
- [Staking Lifecycle](https://docs.stargate.vechain.org/overview/staking-lifecycle)
- [NFT Tiers](https://docs.stargate.vechain.org/overview/nft-tiers)
- [Rewards Structure](https://docs.stargate.vechain.org/overview/rewards-structure)
- [Validators](https://docs.stargate.vechain.org/overview/validators)
- [Developer API](https://docs.stargate.vechain.org/for-developers/api)
- [Contracts](https://docs.stargate.vechain.org/for-developers/contracts)
- [StarGate Contracts (GitHub)](https://github.com/vechain/stargate-contracts)
- [StarGate dApp](https://app.stargate.vechain.org/)

## Governance (VeVote)
- [VeVote Documentation](https://docs.vevote.vechain.org/)
- [VeVote Platform](https://vevote.vechain.org/)
- [VeVote Monorepo (GitHub)](https://github.com/vechain/vevote)
- [VeVote Contracts (GitHub)](https://github.com/vechain/vevote-contracts)
- [VeChain Governance Overview](https://docs.vechain.org/introduction-to-vechain/about-the-vechain-blockchain/governance)

## VeChain Ecosystem
- [VeChain Official Website](https://www.vechain.org/)
- [VeChain GitHub Organization](https://github.com/vechain)
- [VeChain Improvement Proposals (VIPs)](https://github.com/vechain/VIPs)
- [VeChain Explorer (Mainnet)](https://explore.vechain.org/)
- [VeChain Explorer (Testnet)](https://explore-testnet.vechain.org/)

## Network Endpoints

- **Mainnet**: `https://mainnet.vechain.org`
- **Testnet**: `https://testnet.vechain.org`
- **Thor Solo (local)**: `http://localhost:8669`

## Thor REST API (direct HTTP, no SDK needed)

For lightweight reads without the SDK (e.g., serverless functions, scripts):

```bash
# VET balance
GET /accounts/{address}
# → { "balance": "0x...", "energy": "0x...", "hasCode": false }

# Token balance (balanceOf via simulated call)
POST /accounts/*
{
  "clauses": [{ "to": "0xTokenAddress", "value": "0", "data": "0x70a08231000000000000000000000000{address}" }]
}
# → { "results": [{ "data": "0x...", "gasUsed": ... }] }
```

**Common mistake:** Do NOT `POST /accounts/{tokenAddress}` — token reads use `POST /accounts/*` with clauses.

## Token Registry

Public JSON registry of VeChain tokens with metadata and icons:

- **Mainnet**: `https://vechain.github.io/token-registry/main.json`
- **Testnet**: `https://vechain.github.io/token-registry/test.json`
- **Icon URL**: `https://vechain.github.io/token-registry/assets/{icon}` (where `icon` is the hash filename from the JSON)

## VET Domain Resolution

For `.vet` domain lookups outside of React (in React, use VeChain Kit's `useVechainDomain` hook instead):

- **Public API**: `https://vet.domains/api/lookup/name/{domain}` → `{ "addresses": [{ "address": "0x..." }] }`

## App-Hub Submission

To list your dApp in the VeChain ecosystem directory:

1. Fork [vechain/app-hub](https://github.com/vechain/app-hub)
2. Create `apps/{reversed-domain}/` (e.g., `apps/org.myapp/`)
3. Add `manifest.json` + `logo.png` (512x512)
4. PR to the `master` branch
