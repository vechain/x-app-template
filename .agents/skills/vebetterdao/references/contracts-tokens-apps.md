# VeBetterDAO Contracts — Tokens & X2Earn Apps

## When to use

Use when the user asks about: B3TR, VOT3, Emissions, XAllocationVoting, XAllocationPool, X2EarnRewardsPool, X2EarnApps, X2EarnCreator, DBAPool, token minting, voting rounds, app submission, endorsement, reward distribution, or impact tracking.

Full source: [github.com/vechain/vebetterdao-contracts](https://github.com/vechain/vebetterdao-contracts)
Auto-generated docs: [vechain.github.io/vebetterdao-contracts](https://vechain.github.io/vebetterdao-contracts/)

---

## Contract Map

```
Emissions ──distribute()──> XAllocationPool + VoterRewards + Treasury + GalaxyMember
                                  │                 │
                    claim()       │    registerVote()│    claimReward()
                         ▼        │                 ▼
               X2EarnRewardsPool  │          VoterRewards
                    │             │                 │
   distributeReward()             │         claimReward()
                    ▼             │                 ▼
               Users (B3TR)       │          Voters (B3TR)
                                  │
                    XAllocationVoting ◄── VOT3 holders vote
                                  │
                    B3TRGovernor ──queue()──> TimeLock ──execute()──> Treasury
```

All upgradeable contracts use **UUPS proxy pattern** with ERC-7201 storage layout.

---

## B3TR (ERC-20 Token)

Capped ERC-20 token. 1B total supply over 12 years.

| Role | Can |
|------|-----|
| `MINTER_ROLE` | `mint(address, amount)` — respects supply cap |
| Admin | `pause()` / `unpause()` — halts all transfers |

Key function: `tokenDetails()` — returns name, symbol, decimals, totalSupply, cap in one call.

## VOT3 (Governance Token, V2)

ERC-20 with voting power. Obtained by converting B3TR 1:1. V2 added NavigatorRegistry integration for delegation lock.

| Function | Description |
|----------|-------------|
| `convertToVOT3(amount)` | Swap B3TR → VOT3 |
| `convertToB3TR(amount)` | Burn VOT3 → get B3TR back (only self-converted amount, not VOT3 received from others). Blocked for delegated amount |
| `delegate(delegatee)` | Delegate voting power (auto-delegates on first receive) |
| `getQuadraticVotingPower(account)` | Square root of token balance |
| `getPastQuadraticVotingPower(account, timepoint)` | Historical voting power |
| `getNavigatorLockedAmount(address)` | V2: reads delegation amount from NavigatorRegistry |
| `unlockedBalance(address)` | V2: returns `balance - navigatorLockedAmount` (transferable amount) |

**V2 delegation lock:** `_update()` enforces `balanceOf(from) - amount >= NavigatorRegistry.getDelegatedAmount(from)`. VOT3 stores only the registry address — no mapping, no role grant. `balanceOf()` returns full balance including delegated.

Roles: `UPGRADER_ROLE`, `PAUSER_ROLE`.

## Emissions

Manages periodic B3TR distribution across XAllocations, Vote2Earn, Treasury, and GM pool with cycle-based decay.

| Function | Description |
|----------|-------------|
| `distribute()` | Distributes tokens for current cycle |
| `getCurrentCycle()` | Current cycle number |
| `getXAllocationAmount(cycle)` | XAllocation amount for cycle |
| `getVote2EarnAmount(cycle)` | Vote2Earn amount for cycle |
| `isCycleDistributed(cycle)` | Whether cycle was distributed |
| `setCycleDuration()` | Set cycle length |
| `setXAllocationsDecay()` / `setVote2EarnDecay()` | Configure decay rates |
| `setTreasuryPercentage()` / `setGmPercentage()` | Adjust allocation splits |

| Role | Can |
|------|-----|
| `MINTER_ROLE` | Initiate distributions |
| `DECAY_SETTINGS_MANAGER_ROLE` | Modify decay parameters |
| `CONTRACTS_ADDRESS_MANAGER_ROLE` | Update external addresses |

## XAllocationVoting (V9)

Periodic voting rounds for allocating funds to X2Earn apps. Uses quadratic funding with VOT3 voting power at round start. V9 added navigator citizen voting, freshness multiplier, and external library architecture.

| Function | Description |
|----------|-------------|
| `startNewRound()` | Initiate new allocation round. Computes `allocationUsers` (auto-voting + citizens) and `governanceUsers` (citizens only), fetches active proposals, passes to RelayerRewardsPool |
| `castVote(roundId, appIds, voteWeights)` | Vote on apps (weights must exceed threshold). Reverts with `DelegatedToNavigator` for delegated citizens |
| `castVoteOnBehalfOf(voter, roundId)` | Relayer executes auto-vote for user |
| `castNavigatorVote(citizen, roundId)` | V9: vote-or-skip for navigator-delegated citizens using navigator's custom percentages. Skip window: 720 blocks before deadline |
| `toggleAutoVoting(address)` | Enable/disable auto-voting. Reverts for navigators (`NavigatorCannotEnableAutoVoting`) and delegated citizens (`DelegatedToNavigator`) |
| `disableAutoVotingFor(address)` | V9: privileged, called by NavigatorRegistry on delegation |
| `setUserVotingPreferences(appIds)` | Store preferred app IDs for auto-voting |
| `hasUserVotedForApp(roundId, user, appId)` | V9: check if user voted for specific app |
| `setVotingPeriod()` | Configure round duration |
| `setAppSharesCap()` | Max % any single app can receive |
| `setBaseAllocationPercentage()` | Minimum base allocation % |
| `updateQuorumNumerator()` | Adjust quorum threshold |

**V9 freshness:** `countVote()` computes XOR fingerprint of voted app IDs via `FreshnessUtils`, applies freshness multiplier from VoterRewards checkpoints to reward weight (not voting power).

**V9 events:** `NavigatorVoteSkipped(citizen, navigator, roundId)`, `FreshnessMultiplierApplied`.

| Role | Can |
|------|-----|
| `ROUND_STARTER_ROLE` | Start new rounds |
| `GOVERNANCE_ROLE` | Governance operations |

Integrates with: X2EarnApps, VoterRewards, Emissions, VeBetterPassport, NavigatorRegistry, B3TRGovernor, RelayerRewardsPool.

## XAllocationPool

Distributes weekly B3TR emissions to X2Earn apps based on voting results. Apps claim at round end.

| Function | Description |
|----------|-------------|
| `claim(roundId, appId)` | App claims earned B3TR for a round |
| `claimableAmount(roundId, appId)` | Returns allocation breakdown (total, unallocated, team, user pool) |
| `roundEarnings(roundId, appId)` | Calculates allocations from base + variable with per-app caps |
| `getAppShares(roundId, appId)` | Voting percentage (capped) |
| `toggleQuadraticFunding()` | Enable/disable quadratic funding for next round |

Unallocated amounts (apps that didn't claim, rounding remainders) are sent to Treasury.

## X2EarnRewardsPool

Reward pool for X2Earn apps to distribute B3TR to users for sustainable actions.

| Function | Description |
|----------|-------------|
| `deposit(amount, appId)` | Fund rewards pool for an app |
| `withdraw(amount, appId, reason)` | Admin withdrawal to team wallet |
| `distributeReward(appId, amount, receiver)` | Basic reward distribution |
| `distributeRewardWithProof(appId, amount, receiver, proofTypes, proofValues, impactCodes, impactValues, description)` | Distribution with impact tracking |
| `distributeRewardWithProofAndMetadata(...)` | Distribution with additional JSON metadata |
| `distributeRewardForRound(appId, amount, receiver, proof, actionRound)` | Basic distribution attributed to a specific round |
| `distributeRewardWithProofForRound(..., actionRound)` | Distribution with proof attributed to a specific round |
| `distributeRewardWithProofAndMetadataForRound(..., actionRound)` | Distribution with proof + metadata attributed to a specific round |
| `toggleRewardsPoolBalance(appId, enable)` | Enable/disable rewards pool for app |
| `pauseDistribution()` / `unpauseDistribution()` | Admin pause |
| `addImpactKey()` / `removeImpactKey()` | Manage allowed impact categories |

| Role | Can |
|------|-----|
| `IMPACT_KEY_MANAGER_ROLE` | Manage impact keys |
| `CONTRACTS_ADDRESS_MANAGER_ROLE` | Configuration |

Storage maps app IDs to: available funds, rewards pool balances, enabled status, pause state.

## X2EarnApps

Manages X2Earn application lifecycle: submission, endorsement, eligibility, admins/moderators/creators, reward distributors, and metadata.

**App submission & management:**

| Function | Description |
|----------|-------------|
| `submitApp(teamWallet, admin, appName, metadataURI)` | Submit new app (one per creator NFT holder) |
| `hashAppName(appName)` | Get app ID from name |
| `app(appId)` / `apps()` | Get app details |
| `allEligibleApps()` | All apps eligible for voting |
| `setVotingEligibility(appId, bool)` | Toggle voting eligibility |
| `setAppAdmin(appId, newAdmin)` | Change app admin |
| `updateTeamWalletAddress(appId, addr)` | Update team wallet |
| `setTeamAllocationPercentage(appId, pct)` | Set team allocation % |
| `updateAppMetadata(appId, metadataURI)` | Update IPFS metadata |
| `addAppModerator()` / `removeAppModerator()` | Manage moderators (max `MAX_MODERATORS`) |
| `addRewardDistributor()` / `removeRewardDistributor()` | Manage reward distributors (max `MAX_REWARD_DISTRIBUTORS`) |
| `addCreator()` / `removeAppCreator()` | Manage creators (max `MAX_CREATORS`) |
| `removeXAppSubmission(appId)` | Remove app submission (admin) |

**Endorsement system (V8 — flexible, partial points):**

| Function | Description |
|----------|-------------|
| `endorseApp(appId, nodeId, points)` | Endorse with Stargate node (max 49 pts per app per node, 110 total per app) |
| `unendorseApp(appId, nodeId, points)` | Remove endorsement points (0 = remove all) |
| `checkEndorsement(appId)` | Check if threshold met |
| `getScore(appId)` / `getScoreAtTimepoint(appId, block)` | Current / historical endorsement score |
| `getEndorsers(appId)` / `getEndorserNodes(appId)` | List endorsers |
| `getNodeAvailablePoints(nodeId)` | Remaining points for a node |
| `getNodeActiveEndorsements(nodeId)` | All active endorsements for a node |
| `canUnendorse(nodeId, appId)` | Check cooldown |
| `endorsementScoreThreshold()` | Required score (default 100) |
| `maxPointsPerNodePerApp()` / `maxPointsPerApp()` | Configurable caps |

**Query helpers:** `isEligible(appId, timepoint)`, `isEligibleNow(appId)`, `isBlacklisted(appId)`, `isAppUnendorsed(appId)`, `isAppAdmin(appId, addr)`, `isAppModerator(appId, addr)`, `isRewardDistributor(appId, addr)`, `isCreatorOfAnyApp(addr)`, `gracePeriod()`, `cooldownPeriod()`.

| Role | Can |
|------|-----|
| `GOVERNANCE_ROLE` | Manage settings, eligibility, endorsement config |
| `MIGRATION_ROLE` | Seed endorsements during migration |
| `UPGRADER_ROLE` | Upgrade contract |

Limits: `MAX_MODERATORS`, `MAX_REWARD_DISTRIBUTORS`, `MAX_CREATORS` per app.

## X2EarnCreator (NFT)

Non-transferable ERC-721 for VeBetterDAO creators. One per address.

| Function | Description |
|----------|-------------|
| `safeMint(address)` | Mint to recipient (MINTER_ROLE) |
| `selfMint()` | Self-mint when enabled |
| `burn(tokenId)` | Remove token (BURNER_ROLE) |

Blocks all transfers (`transferFrom` reverts). Roles: `MINTER_ROLE`, `BURNER_ROLE`, `PAUSER_ROLE`.

## DBAPool (Dynamic Base Allocation)

Distributes surplus B3TR from XAllocationPool to eligible apps using merit-capped flat distribution.

| Function | Description |
|----------|-------------|
| `distributeDBARewards(roundId, appIds)` | Split pool evenly across apps; cap at 2x vote allocation; overflow to treasury |
| `dbaRoundRewardsForApp(roundId, appId)` | Reward amount for app/round |
| `canDistributeDBARewards(roundId)` | Check distribution eligibility |

Role: `DISTRIBUTOR_ROLE`.
