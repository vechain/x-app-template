
# VeChain Smart Contract Security Checklist

## When to use

Use when the user asks about: security, audit, vulnerability review, reentrancy, access control, or when reviewing contract code.

## Core Principle

Assume the attacker controls:

- Every function argument
- Transaction ordering (front-running, sandwich attacks)
- External contract calls (reentrancy, composability exploits)
- Contract state between transactions

---

## Vulnerability Categories

### 1. Reentrancy Attacks

**Risk**: External calls allow malicious contracts to re-enter your function before state updates complete.

**Attack**: Attacker's `receive()` or `fallback()` function calls back into the vulnerable contract, draining funds.

**Prevention**:

```solidity
// Option 1: Use OpenZeppelin's ReentrancyGuard (recommended)
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient");
        balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// Option 2: Checks-Effects-Interactions pattern
function withdraw(uint256 amount) external {
    // Checks
    require(balances[msg.sender] >= amount, "Insufficient");
    // Effects (update state BEFORE external call)
    balances[msg.sender] -= amount;
    // Interactions (external call last)
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

---

### 2. Access Control Vulnerabilities

**Risk**: Missing or incorrect access control allows unauthorized users to call privileged functions.

**Attack**: Attacker calls admin functions (mint, pause, upgrade, withdraw) directly.

**Prevention**:

```solidity
// Use OpenZeppelin AccessControl or Ownable
import "@openzeppelin/contracts/access/Ownable.sol";

contract Secure is Ownable {
    constructor() Ownable(msg.sender) {}

    function adminAction() external onlyOwner {
        // Only owner can call
    }
}

// For granular roles:
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RoleBased is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        // Only accounts with MINTER_ROLE
    }
}
```

**Critical**: Never use `tx.origin` for authorization:

```solidity
// BAD: vulnerable to phishing via malicious contracts
require(tx.origin == owner, "Not owner");

// GOOD: use msg.sender
require(msg.sender == owner, "Not owner");
```

---

### 3. State-Bound Invariants & Path Symmetry

**Risk**: A protected invariant (e.g. `inscribed_amount ≤ user_balance`, `total_allocated ≤ total_supply`, `sum(child) ≤ parent`) is enforced on **one** path but not on **all** paths that mutate the same state. Users reach the invariant violation by chaining writes through the unguarded path.

**Anti-pattern**: An adjacent guard appears to enforce the invariant, but it actually only enforces the **reverse direction**. Most common with token locks — the lock stops *outflow* below the locked amount, but does **not** bound how high the locked amount itself can be inscribed.

**Real incident** (VeBetterDAO Navigator delegation, May 2026):

```solidity
// VOT3 transfer lock — bounds OUTFLOW only
function _update(address from, ..., uint256 amount) internal {
  uint256 locked = navRegistry.getDelegatedAmount(from);
  require(balanceOf(from) - amount >= locked, "exceeds unlocked"); // outflow check
}

// NavigatorRegistry — INSCRIPTION had no balance check
function delegate(uint256 amount) external {
  require(amount >= MIN_DELEGATION); // ✓
  require(navHasCapacity(amount));   // ✓
  // missing: require(amount <= balanceOf(msg.sender) - alreadyDelegated)
  delegated[msg.sender] += amount;
}
function increaseDelegation(uint256 amount) external { /* same gap */ }
```

A user with 3k VOT3 balance called `delegate(3k)` then `increaseDelegation(3k)` and ended with `delegated = 6k`, balance = 3k`. The transfer lock dutifully froze their entire 3k balance forever, "protecting" the inflated delegation.

**Prevention**:

```solidity
// Add the explicit guard on EVERY write path that grows the locked/inscribed amount
function delegate(uint256 amount) external {
  uint256 available = IVOT3(vot3).unlockedBalance(msg.sender);
  if (amount > available) revert InsufficientUnlockedBalance(msg.sender, amount, available);
  ...
}
function increaseDelegation(uint256 amount) external {
  uint256 available = IVOT3(vot3).unlockedBalance(msg.sender);
  if (amount > available) revert InsufficientUnlockedBalance(msg.sender, amount, available);
  ...
}
```

**The discipline — for every protected invariant `inscribed ≤ resource`**:

1. List **every entrypoint** that increases `inscribed` — `set`, `add`, `increase`, batch helpers, migration paths, auto-clear+rewrite paths.
2. List **every entrypoint** that decreases `resource` — `transfer`, `burn`, `withdraw`, conversion, slashing.
3. Confirm a guard exists on **all** of (1) AND **all** of (2). One side alone is not enough.
4. Pay extra attention to comments that claim "enforced elsewhere" — go read the elsewhere and check the *direction* of the check, not just its presence.

**Common shapes of this bug**:

| Invariant | Inscription paths to guard | Resource paths to guard |
|---|---|---|
| `delegated[user] ≤ balanceOf(user)` | `delegate`, `increaseDelegation`, migration | `transfer`, `burn`, `convertToB3TR` |
| `sum(allocations) ≤ totalShares` | `setAllocation`, `addAllocation` | `mintShares`, `redeemShares` |
| `borrowed ≤ collateral × LTV` | `borrow`, `withdrawCollateral` | `liquidate` (other direction) |
| `staked[user] ≤ approved[user]` | `stake`, `restake`, `compound` | `approve` (decreases), `unstake` |

---

### 4. Integer Overflow/Underflow

**Risk**: Arithmetic operations wrap around, leading to unexpected values.

**Note**: Solidity 0.8+ has built-in overflow checks. However, `unchecked` blocks bypass these.

**Prevention**:

```solidity
// Solidity 0.8+: safe by default
uint256 result = a + b; // Reverts on overflow

// When using unchecked, ensure overflow is impossible by construction
unchecked {
    // ONLY when you've proven overflow cannot happen
    uint256 i = 0;
    i++; // Safe: bounded by loop condition
}

// Be careful with downcasting
uint256 bigValue = 300;
uint8 smallValue = uint8(bigValue); // Silently truncates to 44!

// Use SafeCast for safe downcasting
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
uint8 safeValue = SafeCast.toUint8(bigValue); // Reverts if > 255
```

---

### 5. Front-Running / MEV

**Risk**: Attackers observe pending transactions and submit their own with higher gas priority.

**Attack**: Sandwich attacks on DEX trades, front-running NFT mints, oracle manipulation.

**Prevention**:

```solidity
// Use commit-reveal patterns for sensitive operations
mapping(bytes32 => uint256) public commitments;

function commit(bytes32 hash) external {
    commitments[hash] = block.timestamp;
}

function reveal(uint256 value, bytes32 salt) external {
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, value, salt));
    require(commitments[hash] > 0, "No commitment");
    require(block.timestamp >= commitments[hash] + 10, "Too early"); // ~1 block on VeChain
    delete commitments[hash];
    // Process the revealed value
}

// Use slippage protection for swaps
function swap(uint256 amountIn, uint256 minAmountOut) external {
    uint256 amountOut = calculateOutput(amountIn);
    require(amountOut >= minAmountOut, "Slippage exceeded");
    // Execute swap
}
```

**Note**: VeChain's ~10-second block time and different mempool dynamics make front-running less common than on Ethereum, but it is still possible.

---

### 6. Uninitialized Storage / Proxy Vulnerabilities

**Risk**: Upgradeable contracts can have uninitialized state or storage collisions.

**Attack**: Attacker calls `initialize()` on an uninitialized proxy or exploits storage layout conflicts.

**Prevention**:

```solidity
// Always use initializers for upgradeable contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MyUpgradeable is Initializable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Prevent implementation initialization
    }

    function initialize(uint256 _value) public initializer {
        value = _value;
    }
}
```

- Never add new state variables between existing ones in upgrades
- Use OpenZeppelin's upgrade safety checks
- Always `_disableInitializers()` in the constructor

---

### 7. Denial of Service (DoS)

**Risk**: Attacker makes a function unusable for legitimate users.

**Attack**: Gas griefing, unbounded loops, failed external calls blocking execution.

**Prevention**:

```solidity
// BAD: Unbounded loop over user-controlled array
function distributeAll() external {
    for (uint256 i = 0; i < recipients.length; i++) {
        payable(recipients[i]).transfer(amounts[i]); // DoS if one fails
    }
}

// GOOD: Pull pattern (users withdraw themselves)
mapping(address => uint256) public pendingWithdrawals;

function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0;
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}

// GOOD: Batch with limit
function distributeBatch(uint256 start, uint256 count) external {
    uint256 end = start + count;
    require(end <= recipients.length, "Out of bounds");
    for (uint256 i = start; i < end;) {
        // process
        unchecked { ++i; }
    }
}
```

---

### 8. Oracle Manipulation

**Risk**: Price oracles or data feeds can be manipulated to exploit DeFi protocols.

**Attack**: Flash loan attack manipulates spot price, attacker profits from mispriced assets.

**Prevention**:

```solidity
// Use time-weighted average prices (TWAP) instead of spot prices
// Use multiple oracle sources
// Add circuit breakers for extreme price movements
function getPrice() public view returns (uint256) {
    uint256 price = oracle.getPrice();
    require(price > minPrice && price < maxPrice, "Price out of bounds");
    return price;
}
```

---

### 9. Unsafe External Calls

**Risk**: Low-level calls can fail silently or return unexpected data.

**Prevention**:

```solidity
// BAD: ignoring return value
address(target).call{value: amount}("");

// GOOD: check return value
(bool success, bytes memory returnData) = address(target).call{value: amount}("");
require(success, "Call failed");

// BAD: using transfer (2300 gas limit, can break)
payable(recipient).transfer(amount);

// GOOD: use call with reentrancy protection
(bool success, ) = recipient.call{value: amount}("");
require(success, "Transfer failed");

// For ERC-20 tokens, use SafeERC20
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;

token.safeTransfer(recipient, amount);
token.safeTransferFrom(sender, recipient, amount);
```

---

### 10. Signature Replay

**Risk**: Valid signatures can be reused across transactions, chains, or contexts.

**Prevention**:

```solidity
// Include nonce, chain ID, and contract address in signed data
mapping(address => uint256) public nonces;

function executeWithSignature(
    address to,
    uint256 amount,
    uint256 nonce,
    bytes calldata signature
) external {
    require(nonce == nonces[msg.sender], "Invalid nonce");
    nonces[msg.sender]++;

    bytes32 hash = keccak256(abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR, // includes chain ID and contract address
        keccak256(abi.encode(to, amount, nonce))
    ));

    address signer = ECDSA.recover(hash, signature);
    require(signer == msg.sender, "Invalid signature");
    // Execute action
}
```

---

## Smart Contract Checklist

### Input Validation

- [ ] Validate all function parameters (non-zero addresses, valid ranges)
- [ ] Use `require` or custom errors for all preconditions
- [ ] Validate array lengths match when processing parallel arrays
- [ ] Check for zero amounts in transfer/approval functions

### State-Bound Invariants

- [ ] For each invariant `inscribed ≤ resource`, **every** entrypoint that grows `inscribed` has a guard
- [ ] For each invariant `inscribed ≤ resource`, **every** entrypoint that shrinks `resource` has a guard
- [ ] No comment claims "enforced by X" without a verified read of X confirming the *direction* of the check
- [ ] Sibling entrypoints mutating the same storage share the same guards (e.g. `set` and `add` and `increase`)

### Access Control

- [ ] Every privileged function has appropriate access control
- [ ] Use `Ownable2Step` for ownership transfers
- [ ] Never use `tx.origin` for authorization
- [ ] Admin functions are clearly identified and tested

### Reentrancy

- [ ] Use `ReentrancyGuard` on all functions that make external calls
- [ ] Follow Checks-Effects-Interactions pattern
- [ ] State updates happen before external calls

### Arithmetic

- [ ] Solidity 0.8+ is used (built-in overflow protection)
- [ ] `unchecked` blocks are only used where overflow is provably impossible
- [ ] Safe downcasting with `SafeCast` when needed
- [ ] Division by zero is prevented

### External Interactions

- [ ] Return values of external calls are checked
- [ ] `SafeERC20` is used for token transfers
- [ ] No reliance on `transfer()` or `send()` (use `call` instead)
- [ ] Contract handles the case where external call reverts

### Upgradeable Contracts

- [ ] `_disableInitializers()` in constructor
- [ ] Storage layout preserved across upgrades
- [ ] `initializer` modifier on initialization functions
- [ ] Upgrade authorization properly restricted

---

## Client-Side Checklist

- [ ] Network awareness: never hardcode mainnet endpoints in dev flows
- [ ] Estimate gas before sending transactions
- [ ] Handle transaction confirmation properly (poll receipt)
- [ ] Treat "transaction ID received" as not-final; track confirmation
- [ ] Validate contract addresses against expected values
- [ ] Show clear error messages for revert reasons
- [ ] Handle fee delegation failures gracefully (fallback to user-paid)
- [ ] Never expose private keys in frontend code

---

## VeChain-Specific Security Considerations

- **Dual token model**: Ensure contracts handle both VET and VTHO correctly
- **Multi-clause atomicity**: All clauses revert together; design accordingly
- **Fee delegation**: Validate that delegated transactions are properly authorized
- **Block time**: ~10 seconds; do not rely on sub-block-time precision for security
- **EVM compatibility**: Target `paris` EVM version; newer opcodes will fail
- **Built-in contracts**: Be aware of VeChainThor's genesis contracts and their interfaces

---

## Security Review Procedure

When conducting a security review, follow this four-pass approach to avoid confirmation bias and missed paths.

### Pass 0 — Map paths and invariants

Before looking for bugs, list:

1. **Every entrypoint** that mutates each storage variable (group by storage, not by feature).
2. **Every cross-contract read** the contract makes, and what it assumes about the other contract's state.
3. **Every protected invariant** in the form `X ≤ Y` or `sum(children) ≤ parent` — explicit (in `require`) or implicit (assumed by callers).

For each invariant, check that **every entrypoint that grows the left-hand side** has the guard, AND **every entrypoint that shrinks the right-hand side** has the corresponding guard. Missing path-symmetry on a state-bound invariant is the most common high-severity finding — see category #3.

### Pass 1 — Enumerate (be thorough)

Walk through every contract function and external interaction. For each, check every category in the vulnerability list and checklists above. Report **all** potential findings, even low-confidence ones. Do not self-censor — over-reporting is better than missing a real issue.

### Pass 2 — Challenge (be adversarial)

Re-examine each finding from Pass 1 critically:

- Is this actually exploitable, or only theoretically possible?
- Does the surrounding code (guards, modifiers, call context) already prevent it?
- Am I reporting this because there is evidence, or because the user asked me to find bugs?

Discard findings that cannot survive this scrutiny. Reclassify severity where needed.

### Pass 3 — Classify and report

Present surviving findings grouped by severity (Critical / High / Medium / Low / Informational) with:

- **What**: the vulnerability
- **Where**: contract, function, line
- **Why**: how an attacker exploits it
- **Fix**: concrete remediation

---

## Security Review Questions

Use these as prompts during Pass 1:

1. Can an attacker re-enter any function via an external call?
2. Can an attacker call privileged functions without authorization?
3. Can an attacker manipulate arithmetic to gain an advantage?
4. Can an attacker front-run a transaction to extract value?
5. Can an attacker replay a valid signature in a different context?
6. Can an attacker cause a DoS by making a function revert for everyone?
7. Can an attacker exploit the upgrade mechanism?
8. Can an attacker manipulate oracle data to misvalue assets?
9. **Path-symmetry**: For every guard I see on entrypoint A, does the sibling entrypoint B that mutates the same storage have the same guard? If not — why not?
10. **Direction**: For every guard I rely on, does it bound the value in the direction I think? A check like `balance - amount ≥ locked` bounds *outflow*, not the *inscription* of `locked`.
11. **Sequencing**: Can a user reach state X by chaining N legal calls? `delegate(max) → increase(max)`, `claim → claim`, `register → exit → re-register`, `setRate → setRate → settle`?
12. **Boundaries**: What happens at 0, 1 wei, MIN, MIN-1, MAX, MAX+1, exact-resource, resource+1? Has every boundary been tested, not only the middle of the range?
13. **Cross-contract assumptions**: When I read from contract Y, what if Y returns 0, returns the previous block's value, is paused, has been upgraded, has had its admin role revoked?
14. **State transitions during the action**: What if the navigator dies, the round ends, the cycle rolls over, the allowance is revoked, the balance drops mid-flow?

## Adversarial Path Coverage in Tests

A feature is not done when the happy path is green. Before declaring done, the test suite must cover:

- **All sibling entrypoints** mutating the same storage (writes, reductions, auto-clears, migrations, batch helpers).
- **Sequences a user can chain**: `max → increase`, `delegate → switch → delegate`, `claim → claim again`, `enter → exit → re-enter`.
- **Boundaries**: 0, 1 wei, MIN, MIN-1, MAX, MAX+1, exact-balance, balance+1.
- **Cross-contract assumptions**: stale reads, lazy invalidation, contract paused, oracle returning a different value than last block.
- **State transitions during the action**: counter-party dies mid-flow, round ends, reward cycle rolls over, balance drops between read and write.

"It works for the path I coded" is the bug. The user's path is *every* path the contract permits. Before submitting, write down: "could a user reach state X by any sequence?" — and prove the answer with a test, not by reading code.
