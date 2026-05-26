# Governance (VeVote & VeBetterDAO)

## When to use

Use when the user asks about: voting, proposals, steering committee elections, VOT3 governance, on-chain voting mechanisms.

## Two Governance Systems

| System | Platform | Voting Asset | Purpose |
|--------|----------|-------------|---------|
| **VeVote** | [vevote.vechain.org](https://vevote.vechain.org/) | Stargate NFTs | Protocol upgrades, steering committee elections, network parameters |
| **VeBetterDAO Governor** | VeBetterDAO dApp | VOT3 token | dApp allocation rounds, ecosystem fund distribution, DAO proposals |

---

## VeVote (Protocol Governance)

On-chain governance platform where Validators and Node holders vote on proposals. All votes are recorded on-chain (tamper-proof, publicly verifiable).

### Proposal Types

- **Steering Committee Voting** -- Election of the Board of Steering Committee
- **All Stakeholders Voting** -- Protocol changes (e.g., VIP-253 Hayabusa upgrade)

### Voting Power

Weighted by **Stargate NFT tier level** (highest to lowest):

Mjolnir X → Thunder X → Strength X → VeThor X → Mjolnir → Thunder → Strength → Flash → Lightning → Dawn

Voting units in the contract are scaled by 100 to avoid underflow (e.g., 150 = 1.5x).

### Voting Rules

- Total voting power applied to the option you select
- One vote per wallet per proposal, **cannot be changed**
- Options: **For**, **Against**, **Abstain**
- Power calculated at the moment of vote (not at proposal start)

### Delegation

Via Stargate NFT **Node Manager** feature: an NFT owner assigns a secondary wallet that gains full voting power for managed NFT(s).

### Contract Address

| Contract | Network | Address |
|----------|---------|---------|
| Steering Committee Vote | Mainnet | `0xDBAeC4165A6cff07901C41D3561EEFdCFbc20CB6` |

### Developer Resources

- **Monorepo**: [github.com/vechain/vevote](https://github.com/vechain/vevote) -- `packages/contracts/` + `apps/frontend/`
- **Legacy contracts**: [github.com/vechain/vevote-contracts](https://github.com/vechain/vevote-contracts)
- **Stack**: Solidity + Hardhat (contracts), React + Vite (frontend), VeChain Kit (wallet)

---

## VeBetterDAO Governance

Uses OpenZeppelin **Governor pattern** (AccessControl + UUPSUpgradeable).

### Voting Token: VOT3

- Obtained by swapping B3TR at **1:1 ratio** (auto-delegates to holder on receipt)
- Minimum **1 VOT3** to participate in governance
- See [vebetterdao.md](vebetterdao.md) for B3TR/VOT3 token details and contract addresses

### Proposal Requirements

- Must hold a **GM Moon NFT** (level 2+)
- Must create a **Discourse thread** at least 3 days before submitting

### Proposal Types

- **Actionable**: triggers on-chain action (treasury transfer, contract call)
- **Non-Actionable**: expresses direction/idea without immediate on-chain execution

### Governance Proposals

1. Proposer creates proposal with VOT3 deposit
2. **Deposit threshold**: 2% of total B3TR supply must be deposited in VOT3 → temperature check
3. If threshold reached before waiting period ends → proposal becomes active
4. Voting period opens; quorum: **30% of total VOT3 supply** (FOR + AGAINST + ABSTAIN all count)
5. If quorum met and "yes" > "no" → queued to TimeLock → executed after delay

**Deposits count as allocation voting power**: locked VOT3 deposits are included in the XAllocation snapshot and grant voting power in allocation rounds even while locked.

### Allocation Rounds

- Weekly rounds where VOT3 holders vote on X2Earn app funding
- **100% vote-based** allocation (no base allocation; base allocation % = 0 since Jan 2025)
- **Allocation cap**: 20% per app (ensures at least 6 apps participate)
- **Quadratic Funding** formula: allocation proportional to `(sum of sqrt(votes))^2`, emphasizing number of distinct supporters over vote size. Admins can disable QF (switches to linear; takes effect next round)
- Quorum: **1% of total VOT3 supply**. If not met, distribution still occurs using last valid round's vote percentages. New apps in a failed round only receive base allocation (currently 0%)
- **Snapshot**: VOT3 holdings and completed actions are snapshotted at round start; changes after that don't count
- **Voting**: one vote per user per round; can split across multiple apps (e.g., 30 VOT3 to app A, 70 to app B)
- **Distribution trigger**: `claim()` is public — anyone can call it. VeBetterDAO team runs a scheduler to trigger at each new round
- Unallocated/unclaimed funds go to Treasury

### Vote Delegation

- Auto-delegation enabled: converting B3TR → VOT3 or receiving VOT3 auto-delegates to your address
- **Important for smart contracts**: auto-delegation does NOT work for contracts; if a contract receives VOT3 and wants to participate in governance, it must call `delegate()` manually (one-time)

### Voter Rewards

- **Vote2Earn Pool**: Rewards all participants proportionally to VOT3 balance (linear since round 23; quadratic rewarding disabled)
- **GM Rewards Pool**: 5% of weekly emissions → voters with GM NFT (Moon level 2+), weighted by GM NFT reward weight
- Participation in **both governance proposals and XAllocation votes** counts for rewards

### GM NFT Levels

| Level | Name | B3TR to Upgrade | Reward Weight |
|-------|------|----------------|---------------|
| 1 | Earth | Free (requires governance participation) | -- |
| 2 | Moon | 5,000 | 1.1 |
| 3 | Mercury | 12,500 | 1.2 |
| 4 | Venus | 25,000 | 1.5 |
| 5 | Mars | 50,000 | 2 |
| 6 | Jupiter | 125,000 | 2.5 |
| 7 | Saturn | 250,000 | 3 |
| 8 | Uranus | 1,250,000 | 5 |
| 9 | Neptune | 2,500,000 | 10 |
| 10 | Galaxy | 12,500,000 | 25 |

### Upgradeable Governance Parameters

- **Voting Period**: must equal or be shorter than Emissions cycle
- **Quorum**: 30% of total VOT3 supply
- **Deposit Threshold**: 2% of total B3TR supply (in VOT3)
- **Voting Threshold**: minimum 1 VOT3 to vote
- **Minimum Voting Delay**: 3 days (PENDING → active)
- **Timelock Minimum Delay**: wait time before execution after queuing
- **Function Restrictions**: can enable/disable whitelist of callable contract functions
- **Allocation Cap**: 20% max per app
- **Base Allocation %**: 0% (currently all vote-based)

---

## VePassport (Voting Eligibility)

Verifies wallet authenticity for VeBetterDAO allocation round voting. Requires **3 sustainable actions in the last 12 rounds**.

| Contract | Network | Address |
|----------|---------|---------|
| VePassport | Mainnet | `0x35a267671d8EDD607B2056A9a13E7ba7CF53c8b3` |
