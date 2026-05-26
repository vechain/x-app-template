# Testing Strategy (Hardhat / Thor Solo)

## Testing Pyramid

1. **Unit tests (fast)**: Hardhat with in-memory EVM or Thor Solo
2. **Integration tests (realistic state)**: Thor Solo with on-demand blocks
3. **Network smoke tests**: testnet/mainnet as needed

## Hardhat Testing with VeChain

### When to Use Hardhat Tests

- Fast execution with familiar testing patterns
- ethers.js-compatible contract interaction
- Built-in assertion helpers (Chai matchers)
- Snapshot/revert for state isolation

### Setup

```bash
npm install --save-dev hardhat @vechain/sdk-hardhat-plugin
npm install --save-dev @nomicfoundation/hardhat-chai-matchers chai
npm install --save-dev @typechain/hardhat typechain @typechain/ethers-v6
```

### Basic Test Structure

```typescript
import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('MyToken', function () {
  let token: any;
  let owner: any;
  let addr1: any;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    token = await ethers.deployContract('MyToken', [1_000_000]);
    await token.waitForDeployment();
  });

  describe('Deployment', function () {
    it('should set the correct total supply', async function () {
      const totalSupply = await token.totalSupply();
      expect(totalSupply).to.equal(ethers.parseEther('1000000'));
    });

    it('should assign total supply to owner', async function () {
      const ownerBalance = await token.balanceOf(owner.address);
      expect(ownerBalance).to.equal(await token.totalSupply());
    });
  });

  describe('Transfers', function () {
    it('should transfer tokens between accounts', async function () {
      const amount = ethers.parseEther('100');
      await token.transfer(addr1.address, amount);
      expect(await token.balanceOf(addr1.address)).to.equal(amount);
    });

    it('should fail if sender has insufficient balance', async function () {
      await expect(
        token.connect(addr1).transfer(owner.address, 1)
      ).to.be.reverted;
    });

    it('should emit Transfer event', async function () {
      const amount = ethers.parseEther('100');
      await expect(token.transfer(addr1.address, amount))
        .to.emit(token, 'Transfer')
        .withArgs(owner.address, addr1.address, amount);
    });
  });
});
```

### Run Tests

```bash
# Run against Thor Solo (requires running instance)
npx hardhat test --network vechain_solo

# Run with verbose output
npx hardhat test --network vechain_solo --verbose
```

## Thor Solo

A local VeChainThor node for development and testing.

### Docker Setup (Recommended)

```bash
# Start Thor Solo with on-demand block generation
docker run -d \
  --name thor-solo \
  -p 127.0.0.1:8669:8669 \
  vechain/thor:latest solo \
  --on-demand \
  --persist \
  --api-cors '*' \
  --api-addr 0.0.0.0:8669
```

### Key Flags

| Flag | Description |
|------|-------------|
| `--on-demand` | Generate blocks only when transactions are pending |
| `--persist` | Store blockchain data to disk |
| `--api-addr value` | API listening address (default: `localhost:8669`) |
| `--api-cors '*'` | Allow all cross-origin requests |
| `--api-call-gas-limit` | Limit contract call gas (default: 50,000,000) |
| `--verbosity value` | Log verbosity 0-9 (default: 3) |

### Pre-Funded Accounts

Thor Solo generates 10 pre-funded accounts from a built-in mnemonic:

```text
denial kitchen pet squirrel other broom bar gas better priority spoil cross
```

Each account has ample VET and VTHO for development. **Never use this mnemonic for mainnet.**

### API Documentation

Once running, access interactive docs at:

- `http://127.0.0.1:8669/doc/stoplight-ui/`
- `http://127.0.0.1:8669/doc/swagger-ui/`

## Testing Patterns

### Contract Deployment in Tests

```typescript
async function deployFixture() {
  const [owner, addr1, addr2] = await ethers.getSigners();

  const Token = await ethers.getContractFactory('MyToken');
  const token = await Token.deploy(1_000_000);
  await token.waitForDeployment();

  return { token, owner, addr1, addr2 };
}

describe('MyToken', function () {
  it('should work', async function () {
    const { token, owner } = await deployFixture();
    // ...
  });
});
```

### Testing Events

```typescript
it('should emit the correct event', async function () {
  await expect(contract.doSomething(42))
    .to.emit(contract, 'SomethingDone')
    .withArgs(owner.address, 42);
});
```

### Testing Reverts

```typescript
it('should revert with custom error', async function () {
  await expect(contract.withdraw(1000))
    .to.be.revertedWithCustomError(contract, 'InsufficientBalance')
    .withArgs(0, 1000);
});

it('should revert with message', async function () {
  await expect(contract.onlyOwnerAction())
    .to.be.revertedWith('Not authorized');
});
```

### Testing Access Control

```typescript
it('should restrict admin functions', async function () {
  await expect(
    contract.connect(addr1).adminAction()
  ).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
});
```

### Testing Multi-Clause Transactions

```typescript
import { ThorClient } from '@vechain/sdk-network';
import { Clause, Transaction, Address, VET } from '@vechain/sdk-core';

it('should execute multi-clause transaction', async function () {
  const thorClient = ThorClient.at('http://localhost:8669');

  const clauses = [
    Clause.transferVET(Address.of(addr1.address), VET.of(100)),
    Clause.transferVET(Address.of(addr2.address), VET.of(200)),
  ];

  const gasResult = await thorClient.gas.estimateGas(clauses, owner.address);
  // Build, sign, send, verify receipt...
});
```

### Testing Fee Delegation

```typescript
it('should execute with fee delegation', async function () {
  const body = {
    chainTag: 0xa4, // solo chain tag
    blockRef: '0x...',
    expiration: 32,
    clauses,
    gasPriceCoef: 0,
    gas: estimatedGas,
    dependsOn: null,
    nonce: Date.now(),
    reserved: { features: 1 } // Enable VIP-191
  };

  const signedTx = Transaction.of(body).signAsSenderAndGasPayer(
    senderPrivateKey,
    gasPayerPrivateKey
  );

  // Verify the sender paid no VTHO
});
```

## Testing with SDK Directly

For lower-level testing without Hardhat:

```typescript
import { ThorClient } from '@vechain/sdk-network';
import { Clause, Transaction, Mnemonic, Address, VET, HexUInt } from '@vechain/sdk-core';

describe('SDK Direct Tests', () => {
  let thorClient: ThorClient;

  before(() => {
    thorClient = ThorClient.at('http://localhost:8669');
  });

  it('should transfer VET', async () => {
    const mnemonic = 'denial kitchen pet squirrel other broom bar gas better priority spoil cross'.split(' ');
    const privateKey = Mnemonic.toPrivateKey(mnemonic);

    const clauses = [
      Clause.transferVET(
        Address.of('0x7567d83b7b8d80addcb281a71d54fc7b3364ffed'),
        VET.of(100)
      )
    ];

    const gasResult = await thorClient.gas.estimateGas(
      clauses,
      '0x...' // sender address
    );

    // Build and send transaction...
  });
});
```

## Test Layout Recommendation

```text
test/
├── unit/
│   ├── Token.test.ts          # Unit tests
│   ├── Governance.test.ts
│   └── utils.ts               # Shared test utilities
├── integration/
│   ├── FullFlow.test.ts       # Multi-contract integration
│   └── FeeDelegate.test.ts   # Fee delegation scenarios
└── fixtures/
    └── deploy.ts              # Shared deployment fixtures
```

## CI Guidance

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      thor-solo:
        image: vechain/thor:latest
        ports:
          - 8669:8669
        options: >-
          --health-cmd "curl -f http://localhost:8669/blocks/best || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        env:
          THOR_ARGS: "solo --on-demand --api-cors '*' --api-addr 0.0.0.0:8669"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npx hardhat compile
      - run: npx hardhat test --network vechain_solo
```

## Best Practices

- Use Thor Solo with `--on-demand` for fast test cycles
- Use fixtures for consistent contract deployment
- Test both success and failure paths
- Test access control for every privileged function
- Test edge cases (zero amounts, max values, empty arrays)
- Verify events are emitted with correct parameters
- Profile gas usage to catch regressions
- Run integration tests in separate CI stage
- Use Docker for reproducible Thor Solo environments
