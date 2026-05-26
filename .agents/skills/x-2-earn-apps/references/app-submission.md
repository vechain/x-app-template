# Submitting Your App to VeBetterDAO

## When to use

Use when the user asks about: submitting an app, Creator NFT, endorsement process, APP_ID, reward distributor setup, app categories, treasury address, admin address, allocation eligibility, creator NFT minting, blacklisting, team members.

## Submission Process

### 1. Acquire a Creator NFT

Two paths:

- **Application form**: Fill out the form on the VeBetter platform for a background check to verify the team and app legitimacy
- **VeChain Grants**: Apply at [vechain.org/grants](https://vechain.org/grants/) — if successful, receive funding AND a Creator NFT

### 2. On-Chain App Submission

After receiving the Creator NFT, submit the app on-chain for endorsement consideration. This registers the app on the VeBetter platform.

**Required information at submission:**

| Field | Description |
|-------|-------------|
| **Treasury address** | Where B3TR tokens go when you withdraw from weekly allocations (for marketing, team shares, etc.). Can be a multi-sig or simple EOA |
| **Admin address** | Has full control: can update app details, change treasury address, transfer ownership. Can be a multi-sig or simple EOA. Can be the same as treasury |

### 3. Connect with Endorsers

The Creator NFT grants access to the **VeBetter XApps Creators Discord server** where you can network with VeChain node holders who may endorse your app.

### 4. Get Endorsed

The app needs a cumulative endorsement score of **100** from VeChain node holders. Once reached, the app is officially added to VeBetterDAO and becomes eligible for weekly B3TR funding through allocation rounds.

---

## After Submission

### Your APP_ID

Once added, you receive an **APP_ID** that VeBetterDAO and other projects use to identify your app. You will need this for all reward distribution calls.

### Add a Reward Distributor

Use your **Admin address** to add a **Reward Distributor** — the address (contract or wallet) that will call `distributeReward` on `X2EarnRewardsPool`.

**Important**: The reward distributor address can also withdraw funds. Protect its access carefully.

### First B3TR Allocation

You will receive your first B3TR tokens **at least one week after joining**, after at least one voting round completes. Plan for users discovering your app before you can distribute rewards — handle this gracefully in your UX.

---

## App Categories

Select up to **2 categories** at submission. Categories are stored by `id`; the `name` is the display label in the VeBetterDAO UI.

```typescript
[
  { "id": "others",                        "name": "Others" },
  { "id": "education-learning",            "name": "Learning" },
  { "id": "fitness-wellness",              "name": "Lifestyle" },
  { "id": "green-finance-defi",            "name": "Web3" },
  { "id": "green-mobility-travel",         "name": "Transportation" },
  { "id": "nutrition",                     "name": "Food & Drinks" },
  { "id": "plastic-waste-recycling",       "name": "Recycling" },
  { "id": "renewable-energy-efficiency",   "name": "Energy" },
  { "id": "sustainable-shopping",          "name": "Shopping" },
  { "id": "pets",                          "name": "Pets" }
]
```

**Note**: If submitting a native application, link a landing page to your app.

---

## X2Earn Creator NFT

The Creator NFT authorizes app submissions and provides access to endorsers. It is the entry point to the VeBetterDAO ecosystem for app creators.

### Key Properties

| Property | Detail |
|----------|--------|
| **Standard** | ERC721 (non-transferable) — OpenZeppelin implementation |
| **Minting authority** | X2Earn App Review Panel only |
| **Max per user** | 1 NFT per user, regardless of number of apps |
| **Transferability** | Non-transferable — cannot be sold or transferred |
| **Contract** | `X2EarnCreator` (mainnet: `0xe8e96a768ffd00417d4bd985bec9EcfC6F732a7f`) |

### Team Members

- After initial submission, the app **admin** can add up to **2 additional creators** (max 3 per app)
- Each additional creator receives their own Creator NFT
- Additional creators are restricted to their assigned app only — they cannot use their NFT to submit new apps
- Each creator is associated with exactly **one app**

### Blacklisting and Burn

- If an app is **blacklisted** and the creator is not associated with any other active app, their Creator NFT is **burned**
- This prevents blacklisted creators from submitting new projects without re-approval
- Creators must go through the full review process again to re-enter the ecosystem
