# VeBetterDAO B3MO Quests

## When to use

Use when the user asks about: B3MO quests, quests, `/b3mo-quests`, `B3TRChallenges`, `SplitWin`, `MaxActions`, quest invitations, joining/leaving/declining quests, claim/refund flows, quest indexer endpoints, or the B3MO quests frontend.

## What are B3MO Quests?

B3MO Quests are peer-to-peer or sponsored competitions where users complete X2Earn app actions to win B3TR.

Naming rule: call the feature **B3MO Quests** or **quests** in prose and user-facing copy. `challenge` only appears where it is still the technical contract/API/code name, such as `B3TRChallenges`, `getChallengeStatus`, or `/api/v1/b3tr/challenges`.

Two core modes:

- `MaxActions`: capped participant pool; top scorer(s) win the pool.
- `SplitWin`: sponsored-only, uncapped joins; first users reaching the threshold claim fixed prize slots.

Quest kind:

- `Stake`: participants put up stake; winners/refunds depend on settlement.
- `Sponsored`: creator funds prize pool; users join without staking.

Visibility:

- `Public`: discoverable and joinable while pending.
- `Private`: join via invitation.

## Core Contract

- Contract: `B3TRChallenges`
- Interface: `IChallenges`
- Types library: `ChallengeTypes`
- Frontend config address commonly exposed as `challengesContractAddress`
- Frontend ABI usually comes from `B3TRChallenges__factory`

Key statuses:

- `Pending`: created, joinable/acceptable, not started.
- `Active`: started; participants can accumulate actions.
- `Completed`: settled; winners/refunds can claim depending on mode.
- `Cancelled`: creator cancelled before activation.
- `Invalid`: quest could not activate, usually because constraints were not met.

Important view functions:

- `getChallenge(id)`: full on-chain quest struct/view.
- `getChallengeStatus(id)`: preferred computed status; reflects time-based transitions without `syncChallenge`.
- `getChallengeParticipants(id)`: joined users.
- `getChallengeInvited(id)`: invited users.
- `getChallengeDeclined(id)`: users who declined.
- `getChallengeWinners(id)`: winners for settled or SplitWin claims.
- `getChallengeSelectedApps(id)`: X2Earn apps whose actions count.
- `getParticipantStatus(id, account)`: `None`, `Invited`, `Declined`, `Joined`.
- `isInvitationEligible(id, account)`: whether an account can accept/re-accept.
- `isSplitWinWinner(id, account)`: whether account already won a SplitWin slot.
- `getParticipantActions(id, participant)`: live action count.
- `maxParticipants()`: default max for MaxActions.
- `minBetAmount()`: minimum stake in wei.

Important nuance: after `ChallengeLeft`, `getParticipantStatus` returns `None`, not a stored `Left` state. To detect users who left, consult the `ChallengeLeft` event or an indexer record derived from it.

## Lifecycle Events

All lifecycle events use `challengeId` as the first indexed topic because this is the contract-level identifier.

- `ChallengeCreated`: indexed `creator` and `endRound`; new quest and metadata.
- `SplitWinConfigured`: SplitWin config, emitted after creation.
- `ChallengeInviteAdded`: indexed `invitee`; private invitation.
- `ChallengeJoined`: indexed `participant`; user joined.
- `ChallengeLeft`: indexed `participant`; user left before start.
- `ChallengeDeclined`: indexed `participant`; invitee declined.
- `ChallengeCancelled`: creator cancelled pending quest.
- `ChallengeActivated`: pending to active.
- `ChallengeInvalidated`: pending to invalid.
- `ChallengeCompleted`: active to completed, includes settlement data.
- `ChallengePayoutClaimed`: indexed `account`; MaxActions payout claimed.
- `ChallengeRefundClaimed`: indexed `account`; cancelled/invalid refund claimed.
- `SplitWinPrizeClaimed`: indexed `winner`; SplitWin slot prize claimed.
- `SplitWinCreatorRefunded`: indexed `creator`; creator reclaimed unclaimed SplitWin slots after end.

## Settlement and Claim Rules

Settlement modes:

- `None`: no settlement yet.
- `TopWinners`: best scorers claim prize.
- `CreatorRefund`: creator recovers pool.
- `SplitWinCompleted`: SplitWin completed after slots are claimed or reclaimed.

Frontend/domain flags commonly derived from raw state:

- `canJoin`: pending, public, not joined, not creator, not at participant limit.
- `canAccept`: pending invite or eligible invitee, not at limit. Declined users may re-accept if still eligible.
- `canComplete`: MaxActions active quest past `endRound`, creator or joined participant.
- `canClaim`: MaxActions completed quest where joined participant has `bestScore`, or creator refund settlement applies.
- `canClaimSplitWin`: SplitWin active, joined, in time window, actions >= threshold, slots left.
- `canClaimCreatorSplitWinRefund`: SplitWin creator, current round after `endRound`, slots left, creator refund not yet claimed.
- `canRefund`: cancelled or invalid quest; for `Stake`, joined users refund; for `Sponsored`, creator refunds.

Wei boundary: `stakeAmount`, `totalPrize`, and `prizePerWinner` are wei on-chain. Convert with `formatEther` at frontend boundaries. `threshold` and `bestScore` are action counts, not B3TR amounts.

## Frontend / Indexer Pattern

Common route: `/b3mo-quests`.

Recommended data split:

- List sections use indexer endpoints for pagination and segmentation.
- Detail views can still use direct contract calls plus event scans when immediate post-transaction freshness matters.
- Contract multicall enriches indexer quest IDs with live computed status, participant status, invitation eligibility, winner state, action counts, and claim flags.

Typical indexer endpoints:

- `GET /api/v1/b3tr/challenges?status=...`: public quests by status.
- `GET /api/v1/b3tr/users/{wallet}/challenges?filter=...`: wallet-scoped quest sections.

Typical wallet filters:

- `NeededAction`: invites, claimable, finalizable, reclaimable.
- `MyChallenges`: user-created or participating current quests.
- `OpenToJoin`: joinable quests.
- `OthersActive`: active public/social discovery quests.
- `History`: terminal quests plus left/declined current quests.

After write transactions, invalidate all quest query keys and schedule delayed refetches to catch indexer/event lag.

## UX and Copy Conventions

- User-facing copy should say **B3MO Quest(s)** or **Quest(s)**.
- Avoid saying "challenge" in product copy, docs headings, and feature descriptions.
- Keep `challenge` only for existing contract/API/code identifiers.
- Status labels should come from a shared helper, not handwritten string formatting.
- Action buttons should be driven by domain flags (`canJoin`, `canAccept`, `canClaim`, etc.), not duplicated UI logic.

## Implementation Rules

- Prefer `getChallengeStatus(id)` over stored struct status for read paths.
- Keep event-derived states when the contract does not store them directly, especially users who left and claim history.
- For invited users leaving a pending quest, leave + decline may need to be chained so the user does not remain invitation-eligible.
- Do not format action counts as token amounts.
- Preserve fast post-transaction UX with broad invalidation plus delayed refetches.
