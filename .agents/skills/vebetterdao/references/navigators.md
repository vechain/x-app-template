# Navigators (Delegation & Multipliers)

## When to use

Use when the user asks about: navigators, delegation, navigator staking, freshness multiplier, governance intent multiplier, navigator fees, slashing, NavigatorRegistry, or professional voting delegates.

For full implementation detail, use the dedicated **vebetterdao-navigators** skill.

## Overview

Navigators are professional voting delegates who stake B3TR to vote on behalf of citizens in both allocation rounds and governance proposals. The feature ships in two phases (released together):

1. **Rewards Multipliers** — freshness (allocation) + governance intent multipliers that adjust reward weight
2. **Navigator Delegation System** — staking, delegation, voting, fees, slashing, lifecycle

## Rewards Multipliers

Multipliers adjust reward weight only — on-chain voting power is never modified. Scale: basis points (10000 = 1x). Stored as `Checkpoints.Trace208` in VoterRewards.

### Freshness Multiplier (Allocation Voting)

Applied in `RoundVotesCountingUtils.countVote()` via `FreshnessUtils` library. XOR fingerprint of voted app IDs detects changes.

| Behavior | Multiplier |
|---|---|
| Updated this round | x3 (30000 bp) |
| Updated within 2 rounds | x2 (20000 bp) |
| No update >= 3 rounds | x1 (10000 bp) |

First-time voters get x3. Citizens inherit navigator's freshness.

### Governance Intent Multiplier (Proposal Voting)

Applied in `GovernorVotesLogic` before `registerVote()`. Per-proposal, independent.

| Vote Type | Multiplier |
|---|---|
| For / Against | x1 (10000 bp) |
| Abstain | x0.30 (3000 bp) |

Citizens inherit navigator's decision multiplier. Freshness scales allocation reward weight; intent scales governance reward weight. GM is **not** stacked with them — when the GM pool is funded (v5+ live config), GM accumulates its own separate per-voter weight claimed against the GM pool, independent of allocation/governance reward weight.

## Navigator System

### Registration & Staking
- Permissionless — stake minimum 50,000 B3TR in NavigatorRegistry
- Staked B3TR is converted to VOT3 under the hood — **counts as navigator's voting power** (checkpointed)
- NavigatorRegistry self-delegates on VOT3 during initialization; per-navigator amounts queried via `getStakedAmountAtTimepoint`
- 10:1 delegation ratio: stake >= 10% of total delegated VOT3
- Max stake: 1% of circulating VOT3 (enforced at deposit only)
- On slash/withdraw: VOT3 converted back to B3TR before transfer
- On-chain reports mandatory at least once every 2 rounds

### Delegation
- Citizens delegate **specific VOT3 amount** (not full balance) — stays in wallet, but locked
- VOT3 reads lock from NavigatorRegistry (`getDelegatedAmount`) — no mapping on VOT3
- One navigator per citizen, snapshotted at round start
- Partial undelegation allowed (takes effect next round)
- No personhood check to delegate. Personhood validated at vote time (snapshot); non-person citizens are skipped
- Citizens can't vote manually while delegated
- Auto-voting disabled on delegation

| Function | Purpose |
|---|---|
| `delegate(navigator, amount)` | First-time delegation |
| `increaseDelegation(amount)` | Add more VOT3 |
| `reduceDelegation(amount)` | Partial or full reduction |
| `undelegate()` | Full removal |

### Voting
- **Allocation**: `XAllocationVoting.castNavigatorVote(citizen, roundId)` — navigator's custom percentages (basis points, sum to 10000)
- **Governance**: `B3TRGovernor.castNavigatorVote(proposalId, citizen)` — navigator's decision (For/Against/Abstain)
- Voting power = delegated amount at snapshot (checkpointed), not full balance
- Navigator setting preferences/decisions = their own vote (personal VOT3 + staked B3TR converted to VOT3)

### Rewards & Fees
```
1. Navigator fee = gross * navigatorFeePercentage / 10000 (→ NavigatorRegistry escrow)
2. Relayer fee = calculated on remainder (→ RelayerRewardsPool)
3. Citizen receives the rest
```
- Citizen's own GM level applies. Relayer fee applies to both auto-voters and citizens
- Fee escrow: 4-round rolling unlock in NavigatorRegistry

### Slashing
- **Minor**: 5% of current remaining stake (compounding), reportable by anyone via `reportRoundInfractions(navigator, roundId, proposalIds)` after round ends
- Six infractions: missed allocation vote, missed governance vote, stale preferences (>= 3 rounds), missed report, late preferences, **below minimum stake**
- Infractions 1-5 require delegations at round snapshot; infraction 6 (below min stake) applies regardless of delegations
- Below min stake uses two-checkpoint check: below at round start AND still below at round end — gives navigator one full round to recover
- At most one minor slash per round
- **Major**: governance process, up to 100% of stake + locked fees + removal

### Lifecycle
- **Exit**: `announceExit()` — 1 round notice, self-enforcing via checkpoint timing (no `finalizeExit`)
- **Deactivation**: governance proposal with slash amount
- Both trigger lazy invalidation — citizen delegations void at view level, VOT3 auto-unlocked

### Relayer Integration
- Citizens ARE counted in expected actions: `allocationUsers = autoVoting + citizens`, `governanceUsers = citizens only`
- `castNavigatorVote` includes skip-or-vote logic with 720-block skip window (skips for: citizen not a person at snapshot, navigator dead now, no preferences/decision at skip window)
- Per-user skip tracking in RelayerRewardsPool V3 (`reduceUserAllocationVote`, `reduceUserGovernanceVote`)
- Governance votes registered as `RelayerAction.VOTE` — relayers earn credit

## Contract: NavigatorRegistry

UUPS upgradeable facade with 6 external libraries: NavigatorStakingUtils, NavigatorDelegationUtils, NavigatorVotingUtils, NavigatorFeeUtils, NavigatorSlashingUtils, NavigatorLifecycleUtils.

Key storage:
- `Checkpoints.Trace208 totalDelegatedCitizens` — global citizen count (used by XAllocationVoting.startNewRound)
- `mapping(address => uint256) navigatorCitizenCount` — per-navigator count
- `mapping(navigator => mapping(round => amount))` fee escrow

Key functions: `delegate`, `increaseDelegation`, `reduceDelegation`, `undelegate`, `register`, `addStake`, `reduceStake`, `withdrawStake`, `setAllocationPreferences`, `setGovernanceDecision`, `submitReport`, `announceExit`, `reportRoundInfractions`, `claimFee`, `depositNavigatorFee`.

## Modified Contracts

| Contract | Version | Navigator changes |
|---|---|---|
| VOT3 | V2 | Reads delegation lock from NavigatorRegistry, `unlockedBalance()` |
| XAllocationVoting | V9 | `castNavigatorVote`, `disableAutoVotingFor`, `startNewRound` with citizens + governance |
| B3TRGovernor | V10 | `castNavigatorVote`, `getActiveProposals`, `proposalsForRound`, relayerRewardsPool |
| VoterRewards | V7 | Multiplier checkpoints, navigator fee deduction, intent multiplier |
| RelayerRewardsPool | V3 | Per-user skip tracking, `setTotalActionsForRoundWithGovernance`, activeProposalsForRound |
