# X2Earn App Development Guide

## When to use

Use when the user asks about: building X2Earn apps, distributing B3TR rewards, testing on testnet or solo, reward distributor setup, integration patterns, fund management.

## Requirements

An X2Earn app must:

1. **Distribute B3TR** tokens on VeChain
2. **Submit a proof** (JSON) of the sustainable action the user was rewarded for

Optional but recommended: allow users to **connect their wallet** via [VeChain Kit](https://vechain-kit.vechain.org/).

## Integration Patterns

### Pattern 1: Smart Contract Only

All validation and distribution on-chain. User calls contract directly.

### Pattern 2: Smart Contract + Backend

Backend validates actions, contract distributes rewards.

### Pattern 3: Backend Only (most web2-friendly)

All logic in a backend using `@vechain/sdk-network`. No custom contract needed.

## Contract Addresses

### Mainnet

| Contract | Address |
|----------|---------|
| B3TR | `0x5ef79995FE8a89e0812330E4378eB2660ceDe699` |
| X2EarnApps | `0x8392B7CCc763dB03b47afcD8E8f5e24F9cf0554D` |
| X2EarnRewardsPool | `0x6Bee7DDab6c99d5B2Af0554EaEA484CE18F52631` |
| XAllocationPool | `0x4191776F05f4bE4848d3f4d587345078B439C7d3` |

### Testnet

| Contract | Address |
|----------|---------|
| B3TR | `0x95761346d18244bb91664181bf91193376197088` |
| X2EarnApps | `0x0b54a094b877a25bdc95b4431eaa1e2206b1ddfe` |
| X2EarnRewardsPool | `0x2d2a2207c68a46fc79325d7718e639d1047b0d8b` |
| XAllocationPool | `0x6f7b4bc19b4dc99005b473b9c45ce2815bbe7533` |
| XAllocationVoting | `0x8800592c463f0b21ae08732559ee8e146db1d7b2` |

---

## Test Environment

### Testnet (recommended)

All contracts are pre-deployed. Use the testnet governance dApp:

1. Go to `staging.testnet.governance.vebetterdao.org/apps`
2. Create a new app (auto-mints a Creator NFT)
3. Navigate to `/admin` → "X2Earn Apps" tab → click "Check Endorsement" for your app
4. Start a new round via "Start new round & claim allocations" (may need multiple rounds before B3TR flows)
5. Go to app settings (cog icon) → add your contract/wallet address as a **Reward Distributor**

### Solo Node (local testing)

Requires deploying mock contracts. You need:

- `B3TR_Mock` — fake token to distribute
- `X2EarnAppsMock` — register your app, generate APP_ID, add reward distributors
- `X2EarnRewardsPoolMock` — distribute rewards (can use same contract as mainnet)

Mock contracts available in [x-app-template](https://github.com/vechain/x-app-template) under `contracts/mocks/`.

Deploy script pattern — only deploy mocks on `vechain_solo`:

```typescript
import { ethers, network } from "hardhat";

let REWARD_TOKEN_ADDRESS = "0xE5FEfcB230364ef7f9B5B0df6DA81B227726612b"; // mainnet

export async function deploy() {
    const MySustainableContract = await ethers.getContractFactory("MySustainableContract");
    const myContract = await MySustainableContract.deploy();
    await myContract.waitForDeployment();

    if (network.name === "vechain_solo") {
        // Deploy mocks
        const RewardToken = await ethers.getContractFactory("B3TR_Mock");
        const rewardToken = await RewardToken.deploy();
        REWARD_TOKEN_ADDRESS = await rewardToken.getAddress();

        const X2EarnApps = await ethers.getContractFactory("X2EarnAppsMock");
        const x2EarnApps = await X2EarnApps.deploy();

        const X2EarnRewardsPool = await ethers.getContractFactory("X2EarnRewardsPoolMock");
        const x2EarnRewardsPool = await X2EarnRewardsPool.deploy(
            deployer.address, REWARD_TOKEN_ADDRESS, await x2EarnApps.getAddress()
        );

        // Register app and fund
        await x2EarnApps.addApp(deployer.address, deployer.address, "MySustainableApp");
        const appID = await x2EarnApps.hashAppName("MySustainableApp");
        await rewardToken.approve(await x2EarnRewardsPool.getAddress(), ethers.parseEther("10000"));
        await x2EarnRewardsPool.deposit(ethers.parseEther("2000"), appID);

        // Add contract as distributor and configure
        await x2EarnApps.addRewardDistributor(appID, await myContract.getAddress());
        await myContract.setVBDAppId(appID);
        await myContract.setX2EarnRewardsPool(await x2EarnRewardsPool.getAddress());
    }
}
```

---

## Reward Distribution

### JavaScript (Backend)

Install: `yarn add @vechain/sdk-network @vechain/vebetterdao-contracts`

```typescript
import {
    ProviderInternalHDWallet, ThorClient,
    VeChainProvider, VeChainSigner,
} from "@vechain/sdk-network";
import { X2EarnRewardsPool } from "@vechain/vebetterdao-contracts";

async function rewardUser(address: string) {
    const thor = ThorClient.at(process.env.NODE_URL || "");
    const provider = new VeChainProvider(
        thor,
        new ProviderInternalHDWallet(
            process.env.REWARD_SENDER_MNEMONIC?.split(" ") || []
        )
    );
    const signer = await provider.getSigner();

    const rewardsPool = thor.contracts.load(
        process.env.X2EARN_REWARDS_POOL_ADDRESS || "",
        X2EarnRewardsPool.abi,
        signer as VeChainSigner
    );

    const tx = await rewardsPool.transact.distributeRewardDeprecated(
        process.env.VEBETTERDAO_APP_ID || "",
        10,
        address,
        JSON.stringify({
            version: 2,
            description: "User refilled water from a sustainable source",
            proof: { image: "https://image.png", link: "https://twitter.com/tweet/1" },
            impact: { carbon: 100, water: 200 },
        })
    );
    await tx.wait();
}
```

**Note**: the JS examples above use `distributeRewardDeprecated` (legacy JSON string format). For new apps, prefer `distributeRewardWithProof` with typed arrays — see the **vebetterdao** skill for the typed API.

**Critical**: the PUBLIC ADDRESS of the wallet calling `distributeReward` must be registered as a Reward Distributor for your app via the governance dApp settings.

### Solidity (On-chain)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IX2EarnRewardsPool.sol";

contract MySustainableAppContract {
    IX2EarnRewardsPool public x2EarnRewardsPool;
    bytes32 public VBD_APP_ID;

    mapping(uint256 => bool) public rewardClaimed;

    constructor(IX2EarnRewardsPool _pool, bytes32 _appId) {
        x2EarnRewardsPool = _pool;
        VBD_APP_ID = _appId;
    }

    /// @notice Claim reward for a validated sustainable action
    /// @dev Contract address must be registered as Reward Distributor
    function claimReward(uint256 _actionId) external {
        // ... validate action is approved and unclaimed

        x2EarnRewardsPool.distributeReward(
            VBD_APP_ID,
            actions[_actionId].rewardAmount,
            msg.sender,
            "" // proof can be empty or JSON string
        );

        rewardClaimed[_actionId] = true;
    }
}
```

**Critical**: the contract address must be set as a **Reward Distributor** on the governance dApp before it can call `distributeReward`.

**Round attribution**: if your app lets users accumulate actions and claim later, use the `ForRound` variants (`distributeRewardForRound`, `distributeRewardWithProofForRound`, `distributeRewardWithProofAndMetadataForRound`) to attribute actions to the round they were performed in. These accept an additional `actionRound` parameter (must be > 0) representing the round ID when the action happened. This prevents users from stacking actions across rounds.

---

## Managing Distributor Funds

Apps receive B3TR from weekly allocation rounds into `X2EarnRewardsPool`. The admin can split tokens between two pools:

- **Distributable rewards pool** — available for user rewards via `distributeReward`
- **Treasury pool** — withdrawable by admin to team wallet for operations

### Key operations

| Action | Dashboard | Contract call |
|--------|-----------|--------------|
| Refill rewards pool | Add funds via VBD dashboard | `X2EarnRewardsPool.increaseRewardsPoolBalance(appId, amount)` |
| Toggle rewards pool | Settings toggle | `X2EarnRewardsPool.toggleRewardsPoolBalance(appId, enable)` |
| Pause distribution | Settings toggle | `X2EarnRewardsPool.pauseDistribution()` |
| Withdraw to team wallet | Dashboard | `X2EarnRewardsPool.withdraw(amount, appId, reason)` |

**New apps**: the rewards pool feature is enabled by default. You must **immediately refill** the rewards pool after joining, up to the amount you want to distribute. If the pool reaches 0, distribution will fail until refilled or the feature is disabled.

---

## Developer Resources

- **X-App-Template**: [github.com/vechain/x-app-template](https://github.com/vechain/x-app-template) — demo sustainability app with mocked contracts
- **VeBetterDAO Contracts**: [github.com/vechain/vebetterdao-contracts](https://github.com/vechain/vebetterdao-contracts) — full source for ABI/TypeChain generation
- **Test dApp**: [staging.testnet.governance.vebetterdao.org](https://staging.testnet.governance.vebetterdao.org/apps)
- **Docs**: [docs.vebetterdao.org/developer-guides](https://docs.vebetterdao.org/developer-guides)
