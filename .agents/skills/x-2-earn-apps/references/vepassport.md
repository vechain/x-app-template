# VePassport (Sybil Resistance)

## When to use

Use when the user asks about: VePassport, personhood check, bot detection, Sybil resistance, bot signaling, whitelisting, blacklisting, isPerson, proof of participation, proof of investment, passport delegation, KYC.

## Overview

VePassport determines whether a wallet belongs to a real person or a bot. Used by VeBetterDAO for voting eligibility and available to all X2Earn apps for Sybil resistance.

**Contract**: `0x35a267671d8EDD607B2056A9a13E7ba7CF53c8b3` (mainnet)

Source: [github.com/vechain/vebetterdao-contracts](https://github.com/vechain/vebetterdao-contracts)

---

## Personhood Check

```solidity
interface IVeBetterPassport {
    function isPerson(address user) external view returns (bool person, string memory reason);
    function isPersonAtTimepoint(
        address user,
        uint48 timepoint
    ) external view returns (bool person, string memory reason);
}
```

The check evaluates these criteria in order:

1. If the address has **delegated** their passport → not a person
2. If the address is **whitelisted** → is a person
3. If the address is **blacklisted** → not a person
4. If flagged as a bot above the **signaling threshold** → not a person
5. If sufficient **participation** in previous/current rounds → is a person
6. If holds a **GM NFT level 2+** → is a person
7. If none of the above → not a person

### Currently Enabled Checks

Not all checks are active. Currently only **delegation** and **Proof of Participation** are enabled. The VeBetter team can enable/disable checks; future governance by the DAO.

### Historical Check

`isPersonAtTimepoint` verifies personhood at a specific past block. Used by governance contracts during voting to check if a user was a person at round start. Only delegation and proof of investment support historical checks — whitelisting, blacklisting, bot signaling, and participation use current block data.

---

## Proof Modules

### Proof of Participation

Users must complete **3 sustainable actions within a 12-round (week) period** to be considered a person.

An action = receiving a reward from an X2Earn app. Points accumulate based on the app's security level:

| App Security Level | Points per Action |
|-------------------|-------------------|
| None | 0 |
| Low | 100 |
| Medium | 200 |
| High | 400 |

### Proof of Investment

Verified through the **GM NFT level** the wallet holds. A GM NFT level 2+ indicates significant investment (upgrading costs B3TR), suggesting the wallet is genuine.

**Status**: Integrated but not currently enabled as a standalone check.

### Proof of Identity (Future)

Various KYC levels from social profile linking to full identity verification. Optional. Not yet implemented.

---

## Bot Signaling

Authorized apps can flag suspicious addresses (bots, scammers). If a user's signal count exceeds the threshold, they fail the personhood check.

### Contract Interface

```solidity
interface IVeBetterPassport {
    function signalingThreshold() external view returns (uint256);
    function signaledCounter(address _user) external view returns (uint256);
    function appSignalsCounter(bytes32 _app, address _user) external view returns (uint256);
    function appTotalSignalsCounter(bytes32 app) external view returns (uint256);
    function signalUserWithReason(address _user, string memory reason) external;
    function resetUserSignalsByAppWithReason(address user, string memory reason) external;
}
```

### Key Functions

| Function | Description |
|----------|-------------|
| `signaledCounter(user)` | Total times a user has been signaled across all apps |
| `appSignalsCounter(app, user)` | Times a user has been signaled by a specific app |
| `signalingThreshold()` | Current threshold — exceeding this fails personhood check |
| `signalUserWithReason(user, reason)` | Flag a user as suspicious |
| `resetUserSignalsByAppWithReason(user, reason)` | Clear signals for a user (VeBetter or selected apps) |

### JavaScript Example

```typescript
import {
    ThorClient,
    ProviderInternalBaseWallet,
    VeChainProvider,
} from "@vechain/sdk-network";

// Connect to network
const thor = ThorClient.at("https://mainnet.vechain.org");
const wallet = new ProviderInternalBaseWallet([
    { privateKey: Buffer.from(privateKey.slice(2), "hex"), address },
]);
const provider = new VeChainProvider(thor, wallet, false);
const signer = await provider.getSigner(address);

// Load VePassport contract
const passport = thor.contracts.load(
    "0x35a267671d8EDD607B2056A9a13E7ba7CF53c8b3",
    passportAbi,
    signer,
);

// Check current signal count
const [counter] = await passport.read.signaledCounter(addressToSignal);

// Signal a user
const tx = await passport.transact.signalUserWithReason(
    addressToSignal,
    "Suspicious automated behavior",
);
```

### Permission Setup

App admins can self-assign the `SIGNALER_ROLE`:

```solidity
// Grant signaling permission to a team member
assignSignalerToAppByAppAdmin(bytes32 app, address user)

// Revoke signaling permission
removeSignalerFromAppByAppAdmin(bytes32 app, address user)
```

Community dashboard: [Signal Admin Dashboard](https://vechain-energy.github.io/vebetterdao-signal-admin/)

---

## Whitelisting and Blacklisting

- **Whitelist**: Authorized entities can whitelist addresses (e.g., after KYC). Whitelisted = always a person
- **Blacklist**: Addresses found to be part of fake account networks. Blacklisted = never a person
- Mistakenly blacklisted wallets can request reinstatement

---

## Passport Delegation

VePassport supports delegating your passport to other addresses for interoperability across the VeBetter and VeChain ecosystem. You can also attach other accounts you own to your passport.

**Important**: If you delegate your passport, your original address will NOT be considered a person — the delegated address inherits personhood instead.
