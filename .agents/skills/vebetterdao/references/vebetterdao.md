# VeBetterDAO (X2Earn Sustainability Apps)

## When to use

Use when the user asks about:

- Building X2Earn or sustainability-rewarding apps
- Distributing B3TR token rewards to users
- VeBetterDAO allocation rounds and voting
- Submitting an app to VeBetterDAO
- B3TR / VOT3 tokens
- Sustainability proofs and impact tracking

## What is VeBetterDAO?

VeBetterDAO is a DAO on VeChainThor that incentivizes sustainable behavior through token rewards. Developers build **X2Earn apps** (sustainability-focused applications) that reward users with **B3TR tokens** for performing verifiable sustainable actions -- recycling, reducing carbon footprints, buying sustainable goods, etc.

The community governs fund allocation through weekly **allocation rounds** where VOT3 holders vote on which apps receive funding, using a **quadratic funding** formula.

## Core Tokens

| Token | Purpose |
|-------|---------|
| **B3TR** | Incentive token. Total supply: 1B over 12 years. Earned by users for sustainable actions |
| **VOT3** | Governance token. Obtained by swapping B3TR 1:1. Used to vote on allocation rounds. **Restriction**: you can only convert back to B3TR the amount you originally converted — VOT3 received from other wallets cannot be converted |

## Architecture Overview

```
B3TR Token Emissions (weekly, 12-year schedule)
        |
        v
  +-----+------+--------+
  |             |        |
  v             v        v
XAllocation   Vote2Earn  Treasury
  Pool         Pool
  |
  v
XAllocationVoting (Quadratic Funding, VOT3-weighted)
  |
  v
Per-App Allocation (base + variable based on votes)
  |
  v
X2EarnRewardsPool (apps distribute to users)
  |
  v
Users receive B3TR for sustainable actions
```

## Three Integration Patterns

### Pattern 1: Smart Contracts Only
All reward validation and distribution logic on-chain via a custom Solidity contract that calls `X2EarnRewardsPool`.

### Pattern 2: Smart Contracts + Backend
Validation logic in a backend, distribution triggered through a smart contract.

### Pattern 3: Backend Only (most web2-friendly)
All logic in a traditional backend using `@vechain/sdk-network` to interact with `X2EarnRewardsPool` directly. No custom smart contract deployment needed.

## Reward Distribution

### Solidity: Basic Reward Distributor

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IX2EarnRewardsPool {
    function distributeReward(
        bytes32 appId,
        uint256 amount,
        address receiver,
        string memory proof
    ) external;

    function distributeRewardWithProof(
        bytes32 appId,
        uint256 amount,
        address receiver,
        string[] memory proofTypes,
        string[] memory proofValues,
        string[] memory impactCodes,
        uint256[] memory impactValues,
        string memory description
    ) external;
}

contract MyRewardDistributor {
    IX2EarnRewardsPool public x2EarnRewardsPool;
    bytes32 public APP_ID;

    constructor(address _x2EarnRewardsPool, bytes32 _appId) {
        x2EarnRewardsPool = IX2EarnRewardsPool(_x2EarnRewardsPool);
        APP_ID = _appId;
    }

    function rewardUser(address receiver, uint256 rewardAmount) external {
        x2EarnRewardsPool.distributeReward(APP_ID, rewardAmount, receiver, "");
    }

    function rewardUserWithProof(
        address receiver,
        uint256 rewardAmount,
        string[] memory proofTypes,
        string[] memory proofValues,
        string[] memory impactCodes,
        uint256[] memory impactValues,
        string memory description
    ) external {
        x2EarnRewardsPool.distributeRewardWithProof(
            APP_ID, rewardAmount, receiver,
            proofTypes, proofValues, impactCodes, impactValues, description
        );
    }
}
```

**Important**: The deployed contract address must be registered as a "Reward Distributor" for your app via the VeBetterDAO governance dApp.

### JavaScript: Backend Reward Distribution

```typescript
import {
    ProviderInternalHDWallet,
    ThorClient,
    VeChainProvider,
} from "@vechain/sdk-network";

const thorClient = ThorClient.at("https://testnet.vechain.org");

const wallet = new ProviderInternalHDWallet(
    mnemonic.split(" "),
    1, 0, true  // testnet
);

const provider = new VeChainProvider(thorClient, wallet);
const signer = await provider.getSigner();

// Load X2EarnRewardsPool contract
const rewardsPool = thorClient.contracts.load(
    X2_EARN_REWARDS_POOL_ADDRESS,
    x2EarnRewardsPoolABI,
    signer
);

// Distribute reward without proofs
await rewardsPool.transact.distributeReward(
    APP_ID,
    ethers.parseEther("10"),  // 10 B3TR
    receiverAddress,
    ""
);

// Distribute reward with sustainability proofs
await rewardsPool.transact.distributeRewardWithProof(
    APP_ID,
    ethers.parseEther("10"),
    receiverAddress,
    ["link", "photo"],                    // proof types
    ["https://proof.url", "ipfs://..."],  // proof values
    ["waste_mass", "carbon"],             // impact codes
    [100, 50],                            // impact values
    "Recycled 100g of plastic waste"
);
```

### Batch Distribution with Multi-Clause

```typescript
import { ABIContract } from '@vechain/sdk-core';

const clauses = users.map(user => ({
    to: X2_EARN_REWARDS_POOL_ADDRESS,
    value: '0x0',
    data: ABIContract.encodeFunctionInput(
        x2EarnRewardsPoolABI,
        'distributeReward',
        [APP_ID, ethers.parseEther(user.amount), user.address, ""]
    ),
}));

// Send as multi-clause transaction
```

## Sustainability Proofs and Impact

### Available Proof Types

`link`, `photo`, `video`, `text`

### Available Impact Codes

`carbon`, `water`, `energy`, `waste_mass`, `education_time`, `timber`, `plastic`, `trees_planted`, `calories_burned`, `sleep_quality_percentage`, `clean_energy_production_wh`

**Mandatory rule**: At least proof OR impact must be provided when using `distributeRewardWithProof`; if neither is provided, the transaction reverts.

### Distribution with Metadata

```solidity
x2EarnRewardsPool.distributeRewardWithProofAndMetadata(
    appId, amount, receiver,
    proofTypes, proofValues,
    impactCodes, impactValues,
    description,
    jsonMetadata  // JSON string with location, referral, campaign info
)
```

## Submitting an App to VeBetterDAO

1. **Acquire a Creator NFT**: Fill out a form on the VeBetter platform for a background check, or apply for a VeChain Grant (receive funding + Creator NFT).
2. **On-Chain Submission**: Submit the app on-chain for endorsement consideration.
3. **Get Endorsed**: Connect with VeChain node holders via the VeBetter XApps Creators Discord. Need a cumulative endorsement score of **100** (a single MjolnirX node = 100 points, Strength node = 2 points).
4. **Enter Allocation Rounds**: Once endorsed to 100, the app is eligible for weekly B3TR funding.

## Contract Addresses

### Mainnet

| Contract | Address |
|----------|---------|
| B3TR | `0x5ef79995FE8a89e0812330E4378eB2660ceDe699` |
| VOT3 | `0x76Ca782B59C74d088C7D2Cce2f211BC00836c602` |
| B3TRGovernor | `0x1c65C25fABe2fc1bCb82f253fA0C916a322f777C` |
| Emissions | `0xDf94739bd169C84fe6478D8420Bb807F1f47b135` |
| GalaxyMember | `0x93B8cD34A7Fc4f53271b9011161F7A2B5fEA9D1F` |
| TimeLock | `0x7B7EaF620d88E38782c6491D7Ce0B8D8cF3227e4` |
| Treasury | `0xD5903BCc66e439c753e525F8AF2FeC7be2429593` |
| VoterRewards | `0x838A33AF756a6366f93e201423E1425f67eC0Fa7` |
| X2EarnApps | `0x8392B7CCc763dB03b47afcD8E8f5e24F9cf0554D` |
| X2EarnRewardsPool | `0x6Bee7DDab6c99d5B2Af0554EaEA484CE18F52631` |
| XAllocationPool | `0x4191776F05f4bE4848d3f4d587345078B439C7d3` |
| XAllocationVoting | `0x89A00Bb0947a30FF95BEeF77a66AEdE3842Fe5B7` |
| VeBetterPassport | `0x35a267671d8EDD607B2056A9a13E7ba7CF53c8b3` |
| X2EarnCreator | `0xe8e96a768ffd00417d4bd985bec9EcfC6F732a7f` |
| NodeManagement | `0xB0EF9D89C6b49CbA6BBF86Bf2FDf0Eee4968c6AB` |
| GrantsManager | `0x055d20914657834c914d7c44bf65b566ab4b45a2` |
| DBAPool | `0x98c1d097c39969bb5de754266f60d22bd105b368` |
| RelayerRewardsPool | `0x34b56f892c9e977b9ba2e43ba64c27d368ab3c86` |

### Testnet

| Contract | Address |
|----------|---------|
| B3TR | `0x95761346d18244bb91664181bf91193376197088` |
| X2EarnApps | `0x0b54a094b877a25bdc95b4431eaa1e2206b1ddfe` |
| X2EarnRewardsPool | `0x2d2a2207c68a46fc79325d7718e639d1047b0d8b` |
| XAllocationPool | `0x6f7b4bc19b4dc99005b473b9c45ce2815bbe7533` |
| XAllocationVoting | `0x8800592c463f0b21ae08732559ee8e146db1d7b2` |
| B3TRGovernor | `0xc30b4d0837f7e3706749655d8bde0c0f265dd81b` |
| VOT3 | `0x6e8b4a88d37897fc11f6ba12c805695f1c41f40e` |
| Emissions | `0x66898f98409db20ed6a1bf0021334b7897eb0688` |
| GalaxyMember | `0x38a59fa7fd7039884465a0ff285b8c4b6fe394ca` |
| Treasury | `0x3d531a80c05099c71b02585031f86a2988e0caca` |
| TimeLock | `0x835509222aa67c333a1cbf29bd341e014aba86c9` |
| VoterRewards | `0x851ef91801899a4e7e4a3174a9300b3e20c957e8` |

## Developer Resources

- **X-App-Template**: [github.com/vechain/x-app-template](https://github.com/vechain/x-app-template) -- Demo sustainability app with mocked contracts
- **VeBetterDAO Contracts**: [github.com/vechain/vebetterdao-contracts](https://github.com/vechain/vebetterdao-contracts) -- Full smart contract source for ABI/TypeChain generation
- **Test Environment**: [staging.testnet.governance.vebetterdao.org](https://staging.testnet.governance.vebetterdao.org/apps) -- Testnet dApp for managing apps and testing distribution
- **Documentation**: [docs.vebetterdao.org](https://docs.vebetterdao.org/)

## Getting Started Checklist

1. Get B3TR tokens on testnet
2. Register your app on the testnet governance dApp
3. Add a reward distributor (the PUBLIC ADDRESS of the wallet or contract calling `distributeRewards`)
4. Choose integration pattern (smart contract, hybrid, or backend-only)
5. Implement reward distribution with sustainability proofs
6. Test on testnet environment
7. Acquire Creator NFT and get endorsed to 100 points for mainnet
