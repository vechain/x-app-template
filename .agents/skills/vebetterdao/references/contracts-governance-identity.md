# VeBetterDAO Contracts — Governance & Identity

## When to use

Use when the user asks about: B3TRGovernor, proposals, VoterRewards, GalaxyMember, Treasury, TimeLock, RelayerRewardsPool, NavigatorRegistry, GrantsManager, B3TRMultiSig, VeBetterPassport, signaling, entity linking, delegation, contract upgradeability, or UUPS proxy pattern.

Full source: [github.com/vechain/vebetterdao-contracts](https://github.com/vechain/vebetterdao-contracts)
Auto-generated docs: [vechain.github.io/vebetterdao-contracts](https://vechain.github.io/vebetterdao-contracts/)

---

## B3TRGovernor (V10)

Main governance contract. Community creates proposals, deposits VOT3, votes with quadratic voting, and executes through TimeLock. V10 added navigator governance voting and relayer integration.

| Function | Description |
|----------|-------------|
| `propose(...)` | Create proposal with deposit requirement and start round |
| `deposit(proposalId, amount)` | Contribute VOT3 to activate proposal |
| `castVote(proposalId, support)` | Vote: 0=against, 1=for, 2=abstain. Reverts with `DelegatedToNavigator` for delegated citizens |
| `castVoteWithReason(proposalId, support, reason)` | Vote with reason string |
| `castNavigatorVote(proposalId, citizen)` | Vote-or-skip for navigator-delegated citizens. Maps navigator decision (1=Against, 2=For, 3=Abstain) to governor support. Registers `RelayerAction.VOTE` in RelayerRewardsPool. Applies intent multiplier |
| `getActiveProposals()` | Returns active proposal IDs (filtered from `proposalsForRound` mapping) |
| `queue(proposalId)` | Prepare approved proposal for execution |
| `execute(proposalId)` | Execute via TimeLock |
| `cancel(proposalId)` | Cancel proposal |
| `withdraw(proposalId)` | Recover deposits after voting |
| `getQuadraticVotingPower(account, timepoint)` | Quadratic voting power |
| `toggleQuadraticVoting(roundId)` | Enable/disable per round |
| `setNavigatorRegistry(address)` | Set NavigatorRegistry address |
| `setRelayerRewardsPool(address)` | Set RelayerRewardsPool address |

**V10 storage:** `INavigatorRegistry navigatorRegistry`, `IRelayerRewardsPool relayerRewardsPool`, `mapping(uint256 => uint256[]) proposalsForRound` (populated at proposal creation).

**V10 events:** `NavigatorGovernanceVoteCast`, `NavigatorGovernanceVoteSkipped`.

**V10 `castNavigatorVote` skip-or-vote flow:**
1. Navigator dead at snapshot → revert `NotDelegatedToNavigator`
2. Navigator dead NOW → skip via `pool.reduceUserGovernanceVote`, emit `NavigatorGovernanceVoteSkipped`
3. Navigator alive + decision set → vote normally
4. Navigator alive + no decision + skip window (720 blocks before deadline) → skip
5. Navigator alive + no decision + skip window not reached → revert `GovernanceSkipWindowNotReached`

Proposal types: `STANDARD` (0) and `GRANT` (1) with type-specific thresholds.

| Role | Can |
|------|-----|
| `GOVERNOR_FUNCTIONS_SETTINGS_ROLE` | Whitelist callable functions |
| `PROPOSAL_EXECUTOR_ROLE` | Execute proposals |
| `PROPOSAL_STATE_MANAGER_ROLE` | Track proposal development |
| `PAUSER_ROLE` | Pause contract |

Integrates with VeBetterPassport for voter identity verification. Logic stored in external libraries (GovernorClockLogic, GovernorConfigurator, GovernorDepositLogic, GovernorFunctionRestrictionsLogic, GovernorProposalLogic, GovernorQuorumLogic, GovernorStateLogic, GovernorVotesLogic).

## VoterRewards (V7)

Calculates and distributes rewards to voters based on voting power and Galaxy Member NFT levels. V7 added rewards multipliers (freshness + governance intent) and navigator fee deduction.

| Function | Description |
|----------|-------------|
| `registerVote(voter, votingPower, roundId)` | Records vote with quadratic-weight calculation |
| `claimReward(cycle, voter)` | Claim cycle-specific rewards. Deducts navigator fee (citizens) then relayer fee (auto-voters + citizens) |
| `getReward(cycle, voter)` | View base reward amount |
| `getGMReward(cycle, voter)` | View GM bonus reward |
| `getRelayerFee(cycle, voter)` | Relayer fee for auto-voting/citizen claims |
| `getNavigatorFee(cycle, voter)` | Navigator fee for citizen claims (V7) |
| `getFreshnessMultipliers(timepoint)` | Returns tier1, tier2, tier3 freshness multiplier values (V7) |
| `getIntentMultipliers(timepoint)` | Returns forAgainst, abstain intent multiplier values (V7) |
| `setFreshnessMultipliers(tier1, tier2, tier3)` | Governance setter for freshness tiers (V7) |
| `setIntentMultipliers(forAgainst, abstain)` | Governance setter for intent values (V7) |
| `setLevelToMultiplier(level, multiplier)` | Queue multiplier change for next cycle |
| `setLevelToMultiplierNow(level, multiplier)` | Apply multiplier immediately |
| `toggleQuadraticRewarding(cycle)` | Enable/disable quadratic rewarding |

**V7 storage:** 5 `Checkpoints.Trace208` for multiplier values (freshnessMultiplierTier1/2/3, intentMultiplierForAgainst, intentMultiplierAbstain), `INavigatorRegistry navigatorRegistry`.

**V7 fee flow:** Navigator fee deducted first from gross reward (citizens only, → NavigatorRegistry escrow), then relayer fee from remainder (auto-voters + citizens, → RelayerRewardsPool). CLAIM action registered for both.

| Role | Can |
|------|-----|
| `VOTE_REGISTRAR_ROLE` | Register votes |
| `DEFAULT_ADMIN_ROLE` | Set multipliers, scaling |
| `GOVERNANCE_ROLE` | Set freshness/intent multipliers (V7) |

Separate GM rewards pool (v5+). Relayer fee integration (v6). Navigator fees + multipliers (v7).

## GalaxyMember (NFT)

ERC-721 with level progression, node attachment, and voting rewards multiplier.

| Function | Description |
|----------|-------------|
| `freeMint()` | Mint level 1 if user participated in governance |
| `upgrade(tokenId)` | Advance level by paying B3TR |
| `select(tokenId)` | Select token for voting rewards multiplier |
| `selectFor(address, tokenId)` | Admin selects for user |
| `attachNode(tokenId, nodeId)` | Attach Stargate NFT for bonus level |
| `detachNode(tokenId, nodeId)` | Remove attached node |
| `setMaxLevel(level)` | Set maximum upgrade level |
| `setB3TRtoUpgradeToLevel(costs)` | Define B3TR cost per level |

| Role | Can |
|------|-----|
| `MINTER_ROLE` | Minting |
| `PAUSER_ROLE` | Pause/unpause |
| `NODES_MANAGER_ROLE` | Node settings |

V6 replaced node management with Stargate NFT integration.

## Treasury

Manages DAO assets. Receives emissions + unallocated funds.

| Function | Description |
|----------|-------------|
| `transferB3TR(to, amount)` | Transfer B3TR |
| `transferVOT3(to, amount)` | Transfer VOT3 |
| `transferVET(to, amount)` | Transfer VET |
| `transferVTHO(to, amount)` | Transfer VTHO |
| `transferTokens(token, to, amount)` | Generic ERC-20 transfer (with limits) |
| `transferNFT(collection, to, tokenId)` | ERC-721 transfer |
| `convertB3TR(amount)` | B3TR → VOT3 |
| `convertVOT3(amount)` | VOT3 → B3TR |
| `setTransferLimitVET(limit)` | Set VET transfer cap |
| `setTransferLimitToken(token, limit)` | Set per-token transfer cap |

All transfers require `GOVERNANCE_ROLE` and contract must be unpaused.

**Transfer limits** (per operation, governance-updatable): 200,000 VET, 200,000 B3TR, 3,000,000 VTHO, 50,000 VOT3. Cannot transfer non-native or non ERC-721/ERC-20 tokens.

## TimeLock

Executes governance actions from B3TRGovernor with a mandatory time delay. B3TRGovernor should be the sole proposer and executor.

## RelayerRewardsPool (V3)

Manages rewards for relayers performing auto-voting and navigator citizen voting. V3 added per-user skip tracking and governance action support.

| Function | Description |
|----------|-------------|
| `claimRewards(roundId, relayer)` | Claim earned rewards |
| `deposit(amount, roundId)` | Fund the pool |
| `registerRelayerAction(relayer, voter, roundId, action)` | Log vote/claim action |
| `calculateRelayerFee(totalReward)` | Compute fee deduction |
| `setTotalActionsForRound(roundId, userCount)` | Legacy: sets expected for auto-voting only |
| `setTotalActionsForRoundWithGovernance(roundId, allocationUsers, governanceUsers, activeProposalIds)` | V3: sets expected actions with separate governance users. Caches activeProposalIds |
| `reduceExpectedActionsForRound(roundId, userCount)` | Bulk reduction for ineligible auto-voting users |
| `reduceUserAllocationVote(roundId, user)` | V3: per-user allocation skip. Auto-reduces claim if all votes skipped |
| `reduceUserGovernanceVote(roundId, user, proposalId)` | V3: per-user/proposal governance skip. Auto-reduces claim if all votes skipped |
| `setVoteWeight()` / `setClaimWeight()` | Adjust action weights |
| `setRelayerFeePercentage()` / `setFeeCap()` | Configure fee structure |
| `setEarlyAccessBlocks()` | Define early access window |
| `registerRelayer(relayer)` / `unregisterRelayer(relayer)` | Manage relayer access |

**V3 storage:** `activeProposalsForRound[roundId]`, `userAllocationVoteReduced[roundId][user]`, `userGovernanceVoteReduced[roundId][user][proposalId]`, `userClaimReduced[roundId][user]`.

| Role | Can |
|------|-----|
| `POOL_ADMIN_ROLE` | Pool administration, relayer management |

## NavigatorRegistry (V1)

UUPS upgradeable contract managing navigator registration, citizen delegation, voting preferences, fees, slashing, and lifecycle. Facade with 6 external libraries. **Staked B3TR is converted to VOT3 under the hood and counts as the navigator's voting power** (checkpointed via `Checkpoints.Trace208`). NavigatorRegistry self-delegates on VOT3 during initialization.

| Function | Description |
|----------|-------------|
| `register(amount, metadataURI)` | Register as navigator by staking B3TR (min 50K, converted to VOT3) |
| `addStake(amount)` / `reduceStake(amount)` | Manage B3TR stake (B3TR↔VOT3 conversion) |
| `withdrawStake(amount)` | Withdraw after exit/deactivation (VOT3→B3TR) |
| `delegate(navigator, amount)` | Delegate VOT3 to navigator |
| `increaseDelegation(amount)` | Add more VOT3 |
| `reduceDelegation(amount)` / `undelegate()` | Reduce or remove delegation |
| `setAllocationPreferences(roundId, appIds, percentages)` | Set allocation vote preferences (basis points, sum to 10000) |
| `setGovernanceDecision(proposalId, decision)` | Set governance vote (1=Against, 2=For, 3=Abstain) |
| `submitReport(metadataURI)` | Submit on-chain report for current round |
| `announceExit()` | Start exit with 1-round notice |
| `reportRoundInfractions(navigator, roundId, proposalIds)` | Report minor infractions for completed round |
| `claimFee(roundId)` | Claim navigator fee after 4-round lock |
| `depositNavigatorFee(navigator, roundId, amount)` | Called by VoterRewards to deposit citizen fee |
| `deactivateNavigator(navigator, slashPct, slashFees)` | Governance action: deactivate + optional slash |
| `getTotalDelegatedCitizensAtTimepoint(timepoint)` | Historical total citizen count |
| `getDelegatedAmountAtTimepoint(citizen, timepoint)` | Historical delegation amount |
| `getStakedAmountAtTimepoint(navigator, timepoint)` | Historical staked amount (used by VotesUtils/GovernorVotesLogic for voting power) |

**Storage:** `Checkpoints.Trace208 totalDelegatedCitizens`, `mapping(address => Checkpoints.Trace208) stakedAmount` (checkpointed for snapshot voting power), `mapping(address => uint256) navigatorCitizenCount`, fee escrow per navigator per round.

**Libraries:** NavigatorStakingUtils, NavigatorDelegationUtils, NavigatorVotingUtils, NavigatorFeeUtils, NavigatorSlashingUtils, NavigatorLifecycleUtils.

| Role | Can |
|------|-----|
| `DEFAULT_ADMIN_ROLE` | Configuration |
| `GOVERNANCE_ROLE` | Deactivation, parameter changes |

## GrantsManager

Milestone-based grant distribution.

| Function | Description |
|----------|-------------|
| `createMilestones(proposalId, milestones)` | Create milestones with IPFS metadata |
| `approveMilestones(proposalId)` | Validate milestone completion |
| `rejectMilestones(proposalId)` | Deny milestones |
| `claimMilestone(proposalId, milestoneIndex)` | Distribute funds for approved milestone |
| `grantState(proposalId)` | Returns: rejected / in development / completed |

| Role | Can |
|------|-----|
| `GRANTS_APPROVER_ROLE` | Approve milestones |
| `GRANTS_REJECTOR_ROLE` | Reject milestones |
| `GOVERNANCE_ROLE` | Protocol governance |

## B3TRMultiSig

Multi-signature wallet requiring multiple owner confirmations (max 50 owners).

| Function | Description |
|----------|-------------|
| `submitTransaction(to, value, data)` | Create pending transaction |
| `confirmTransaction(txId)` | Owner approves |
| `executeTransaction(txId)` | Execute when threshold met |
| `revokeConfirmation(txId)` | Withdraw approval |
| `addOwner(owner)` / `removeOwner(owner)` | Manage owners |
| `changeRequirement(count)` | Adjust confirmation threshold |

## VeBetterPassport

Sybil resistance contract. Determines if a wallet is a real person based on participation score, blacklisting, GM holdings, and entity linking. Used by XAllocationVoting and B3TRGovernor for voter eligibility.

**Core identity checks:**

| Function | Description |
|----------|-------------|
| `isPerson(user)` | Returns `(bool person, string reason)` — checks score, blacklist, GM level |
| `isPersonAtTimepoint(user, timepoint)` | Same check at a specific block |
| `isCheckEnabled(checkType)` | Whether a specific check is active |
| `isWhitelisted(user)` / `isBlacklisted(user)` | Direct status |
| `isPassportWhitelisted(passport)` / `isPassportBlacklisted(passport)` | Checks linked entities too |

**Participation scoring:**

| Function | Description |
|----------|-------------|
| `registerAction(user, appId)` | Register sustainable action (called by apps) |
| `registerActionForRound(user, appId, round)` | Register for specific round |
| `userRoundScore(user, round)` | Score in a specific round |
| `userTotalScore(user)` | Lifetime score |
| `userRoundScoreApp(user, round, appId)` | Per-app per-round score |
| `getCumulativeScoreWithDecay(user, lastRound)` | Decayed cumulative score: `f(t) = a * (1-r)^t` |
| `thresholdPoPScore()` | Required score to be considered a person |
| `appSecurity(appId)` | App security level: `LOW` / `MEDIUM` / `HIGH` |
| `securityMultiplier(security)` | Score multiplier per security level |

**Entity linking** (link multiple wallets to one passport):

| Function | Description |
|----------|-------------|
| `linkEntityToPassport(passport)` | Request linking (entity calls) |
| `acceptEntityLink(entity)` | Passport accepts link |
| `removeEntityLink(entity)` | Remove link (either side) |
| `getPassportForEntity(entity)` | Resolve entity → passport |
| `getEntitiesLinkedToPassport(passport)` | All linked entities |
| `isEntity(user)` / `isPassport(user)` | Check role |
| `maxEntitiesPerPassport()` | Configurable cap |

**Delegation** (delegate personhood to another address):

| Function | Description |
|----------|-------------|
| `delegatePassport(delegatee)` | Request delegation |
| `acceptDelegation(delegator)` | Accept delegation |
| `revokeDelegation()` | Revoke (either side) |
| `getDelegatee(delegator)` / `getDelegator(delegatee)` | Resolve |

**Signaling** (flag suspicious users):

| Function | Description |
|----------|-------------|
| `signalUser(user)` | Signal a user (DEFAULT_ADMIN_ROLE) |
| `signalUserWithReason(user, reason)` | Signal with reason (SIGNALER_ROLE) |
| `resetUserSignalsWithReason(user, reason)` | Reset signals (RESET_SIGNALER_ROLE) |
| `assignSignalerToApp(appId, user)` | Assign app-specific signaler |
| `signaledCounter(user)` | Times user was signaled |
| `signalingThreshold()` | Threshold for auto-blacklist |

| Role | Can |
|------|-----|
| `SETTINGS_MANAGER_ROLE` | Configure thresholds, decay, security |
| `WHITELISTER_ROLE` | Whitelist/blacklist users |
| `ACTION_REGISTRAR_ROLE` | Register actions |
| `ACTION_SCORE_MANAGER_ROLE` | Manage scoring |
| `SIGNALER_ROLE` | Signal users with reason |
| `RESET_SIGNALER_ROLE` | Reset user signals |
| `ROLE_GRANTER` | Grant roles |

## B3TRProxy

EIP-1967 upgradeable proxy. Delegates all calls to the current implementation address. Read implementation via storage slot `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`.

---

## Contract Upgradeability

All upgradeable contracts use **UUPS proxy pattern** with ERC-7201 storage layout.

| Contract | Upgradeable | Authorizer |
|----------|-------------|------------|
| B3TR | No | -- |
| B3TRProxy | No | -- |
| B3TRMultiSig | No | -- |
| B3TRGovernor | Yes | Governance OR DEFAULT_ADMIN |
| Emissions | Yes | UPGRADER_ROLE |
| GalaxyMember | Yes | UPGRADER_ROLE |
| TimeLock | Yes | UPGRADER_ROLE |
| Treasury | Yes | UPGRADER_ROLE |
| VOT3 | Yes | UPGRADER_ROLE |
| VoterRewards | Yes | UPGRADER_ROLE |
| X2EarnApps | Yes | UPGRADER_ROLE |
| X2EarnCreator | Yes | UPGRADER_ROLE |
| X2EarnRewardsPool | Yes | UPGRADER_ROLE |
| XAllocationPool | Yes | UPGRADER_ROLE |
| XAllocationVoting | Yes | UPGRADER_ROLE |
| GrantsManager | Yes | UPGRADER_ROLE |
| DBAPool | Yes | UPGRADER_ROLE |
| RelayerRewardsPool | Yes | UPGRADER_ROLE |
| VeBetterPassport | Yes | UPGRADER_ROLE |
| NavigatorRegistry | Yes | UPGRADER_ROLE |

B3TRGovernor and NavigatorRegistry store logic in external libraries. To upgrade library logic: deploy new library → deploy new implementation linking the library → `upgradeToAndCall`.
