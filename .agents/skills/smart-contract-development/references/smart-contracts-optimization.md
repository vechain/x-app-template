# Smart Contract Gas Optimization on VeChainThor

## When to use

Use when the user needs:
- **Lower VTHO costs**: Reduce gas consumption for frequently-called functions
- **Efficient storage**: Minimize storage slots for cost-critical contracts
- **High-throughput contracts**: Maximize operations per transaction
- **Production readiness**: Optimize before mainnet deployment

## Storage Optimization

### Storage Packing
Pack multiple variables into a single 32-byte storage slot:

```solidity
// Bad: 3 storage slots (96 bytes of storage)
contract Unpacked {
    uint256 amount;    // slot 0 (32 bytes)
    address owner;     // slot 1 (20 bytes, wastes 12)
    bool isActive;     // slot 2 (1 byte, wastes 31)
}

// Good: 2 storage slots
contract Packed {
    uint256 amount;    // slot 0 (32 bytes)
    address owner;     // slot 1, bytes 0-19 (20 bytes)
    bool isActive;     // slot 1, bytes 20 (1 byte, 11 bytes padding)
}
```

### Use Smaller Types When Possible
```solidity
// Good: fits in one slot
struct PackedConfig {
    uint128 maxAmount;     // 16 bytes
    uint64 startTime;      // 8 bytes
    uint32 duration;       // 4 bytes
    uint16 feeRate;        // 2 bytes
    bool isActive;         // 1 byte
    uint8 tier;            // 1 byte
}                          // Total: 32 bytes = 1 slot
```

### Mapping vs Array
- Use mappings for key-value lookups (O(1) access)
- Use arrays only when you need iteration or ordering
- Avoid unbounded arrays (gas cost scales linearly)

```solidity
// Prefer mapping for lookups
mapping(address => uint256) public balances;

// Use array only when iteration is required
address[] public participants;
mapping(address => bool) public isParticipant; // for O(1) existence check
```

## Gas-Efficient Patterns

### Constants and Immutables
```solidity
// Constants: embedded in bytecode, zero storage cost
uint256 public constant MAX_SUPPLY = 1_000_000e18;
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

// Immutables: set once in constructor, stored in bytecode
address public immutable factory;
uint256 public immutable deployTimestamp;

constructor(address _factory) {
    factory = _factory;
    deployTimestamp = block.timestamp;
}
```

### Custom Errors (Solidity 0.8.4+)
```solidity
// Bad: string revert messages cost gas for storage
require(balance >= amount, "Insufficient balance");

// Good: custom errors are much cheaper
error InsufficientBalance(uint256 available, uint256 required);

if (balance < amount) {
    revert InsufficientBalance(balance, amount);
}
```

### Unchecked Arithmetic
When overflow is impossible by construction:
```solidity
// Safe: i cannot overflow because it's bounded by array length
for (uint256 i = 0; i < arr.length;) {
    // process arr[i]
    unchecked { ++i; }
}

// Safe: we already checked balance >= amount
unchecked {
    balances[sender] = balance - amount;
}
```

### Calldata vs Memory
```solidity
// Bad: copies array to memory
function process(uint256[] memory data) external { ... }

// Good: reads directly from calldata (cheaper for external functions)
function process(uint256[] calldata data) external { ... }
```

### Short-Circuit Evaluation
```solidity
// Put cheap checks first
require(amount > 0 && balances[msg.sender] >= amount, "Invalid");

// Avoid expensive storage reads when possible
if (cachedValue == 0) {
    cachedValue = expensiveComputation();
}
```

## Assembly Optimization (Advanced)

### Direct Storage Access
```solidity
function getBalance(address account) external view returns (uint256 result) {
    bytes32 slot = keccak256(abi.encode(account, uint256(0))); // mapping slot
    assembly {
        result := sload(slot)
    }
}
```

### Efficient Hashing
```solidity
function efficientHash(bytes32 a, bytes32 b) internal pure returns (bytes32 result) {
    assembly {
        mstore(0x00, a)
        mstore(0x20, b)
        result := keccak256(0x00, 0x40)
    }
}
```

### Zero-Value Checks
```solidity
function isZeroAddress(address addr) internal pure returns (bool result) {
    assembly {
        result := iszero(addr)
    }
}
```

## Batch Operation Patterns

### Batch Transfers
```solidity
function batchTransfer(
    address[] calldata recipients,
    uint256[] calldata amounts
) external {
    require(recipients.length == amounts.length, "Length mismatch");

    for (uint256 i = 0; i < recipients.length;) {
        _transfer(msg.sender, recipients[i], amounts[i]);
        unchecked { ++i; }
    }
}
```

### Combined with Multi-Clause
For maximum efficiency, combine Solidity batch functions with VeChain's multi-clause transactions:
- Use batch functions for same-contract operations
- Use multi-clause for cross-contract operations

## Event Optimization

### Indexed Parameters
```solidity
// Index fields you'll filter by (max 3 indexed per event)
event Transfer(
    address indexed from,
    address indexed to,
    uint256 value           // not indexed: cheaper to emit
);

// Use anonymous events for maximum gas savings (rare use case)
event Anonymous() anonymous;
```

## Deployment Optimization

### Constructor Arguments
Use `immutable` variables instead of storage for constructor-set values:
```solidity
// Saves ~20,000 gas per read vs storage variable
address public immutable token;

constructor(address _token) {
    token = _token;
}
```

### Optimizer Settings
In `hardhat.config.ts`:
```typescript
solidity: {
  version: '0.8.20',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200     // Lower = cheaper deployment, higher = cheaper calls
    },
    evmVersion: 'paris'
  }
}
```

- `runs: 200` - balanced (good default)
- `runs: 1` - optimize for deployment cost
- `runs: 10000` - optimize for runtime cost (frequently-called contracts)

## Gas Estimation

### Using VeChain SDK
```typescript
import { ThorClient } from '@vechain/sdk-network';

const thorClient = ThorClient.at('https://testnet.vechain.org');

const gasResult = await thorClient.gas.estimateGas(
    clauses,
    callerAddress,
    { gasPadding: 0.2 } // 20% padding for safety
);

console.log('Estimated gas:', gasResult.totalGas);
```

### Gas Profiling in Tests
```typescript
it('should use reasonable gas', async () => {
  const tx = await contract.transfer(recipient, amount);
  const receipt = await tx.wait();
  console.log('Gas used:', receipt.gasUsed.toString());

  // Assert gas is within expected bounds
  expect(receipt.gasUsed).to.be.lessThan(100000);
});
```

## Security vs Optimization Trade-offs

- **Never sacrifice security for gas savings**
- Keep reentrancy guards even if they cost gas
- Keep access control checks even if they cost gas
- Only use `unchecked` when overflow is provably impossible
- Only use assembly for well-understood, critical-path operations
- Always test optimized code thoroughly
