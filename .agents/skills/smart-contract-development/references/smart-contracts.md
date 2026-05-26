# Smart Contracts on VeChainThor (Solidity + Hardhat)

## When to use

Use when the user asks about: Solidity contracts, Hardhat setup, deployment, ERC-20, ERC-721, contract interaction with SDK, built-in contracts, VeChainThor EVM, libraries, contract size, upgradeable contracts.

## Core Advantages
- **EVM Compatibility**: VeChainThor runs standard Solidity contracts
- **Hardhat Integration**: Full Hardhat toolchain with VeChain network support
- **Fee Delegation**: Built-in support for gasless transactions
- **Multi-Clause**: Batch multiple operations in a single transaction

## Project Setup

### Initialize
```bash
mkdir my-vechain-project && cd my-vechain-project
npm init -y
npm install --save-dev hardhat @vechain/sdk-hardhat-plugin
npm install @openzeppelin/contracts@5.0.2
npx hardhat init
```

### Configuration (hardhat.config.ts)
```typescript
import '@vechain/sdk-hardhat-plugin';
import { VET_DERIVATION_PATH } from '@vechain/sdk-core';

const config = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: 'paris'  // VeChainThor aligns with paris EVM
    }
  },
  networks: {
    vechain_solo: {
      url: 'http://localhost:8669',
      accounts: {
        mnemonic: 'denial kitchen pet squirrel other broom bar gas better priority spoil cross',
        count: 3,
        path: VET_DERIVATION_PATH
      },
      debug: true,
      gas: 'auto',
      gasPrice: 'auto'
    },
    vechain_testnet: {
      url: 'https://testnet.vechain.org',
      accounts: {
        mnemonic: process.env.MNEMONIC || '',
        count: 3,
        path: VET_DERIVATION_PATH
      },
      debug: true,
      gas: 'auto',
      gasPrice: 'auto'
    },
    vechain_mainnet: {
      url: 'https://mainnet.vechain.org',
      accounts: [process.env.PRIVATE_KEY || ''],
      debug: false,
      gas: 'auto',
      gasPrice: 'auto'
    }
  }
};

export default config;
```

## EVM Version Compatibility

VeChainThor aligns with the `paris` EVM version. Always set:
```typescript
evmVersion: 'paris'
```

Opcodes introduced after Paris (e.g., `PUSH0` from Shanghai) are NOT supported.

### Pinned Versions

VeChain is not 100% aligned with Ethereum. Pin these to avoid compatibility issues:

- **Solidity**: `0.8.20` — use exact pragma (`pragma solidity 0.8.20;`), not `^0.8.20`
- **OpenZeppelin Contracts**: `5.0.2` — pin exact version, no caret (`@openzeppelin/contracts@5.0.2`)
- **OpenZeppelin Upgradeable**: `5.0.2` — pin exact version (`@openzeppelin/contracts-upgradeable@5.0.2`)

Newer Solidity versions may emit opcodes not yet supported on VeChainThor. Newer OZ versions may use Solidity features or patterns that break on VeChain's EVM.

## Common Contract Patterns

### ERC-20 Token (VIP-180 compatible)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor(
        uint256 initialSupply
    ) ERC20("MyToken", "MTK") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
```

### ERC-721 NFT (VIP-181 compatible)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {}

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // Required overrides
    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
```

### Access Control Pattern
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Governed is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function adminOnlyAction() external onlyRole(ADMIN_ROLE) {
        // ...
    }

    function operatorAction() external onlyRole(OPERATOR_ROLE) {
        // ...
    }
}
```

### Upgradeable Contract (UUPS) — Base Template

Production-ready base for all upgradeable contracts. Uses `AccessControl` (not `Ownable`) and ERC-7201 namespaced storage.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract MyContract is AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    error UnauthorizedUser(address user);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ---------- Storage ------------ //
    // ERC-7201 namespaced storage
    struct MyContractStorage {
        uint256 value;
        // Add fields here. NEVER reorder or remove existing ones.
    }

    // keccak256(abi.encode(uint256(keccak256("storage.MyContract")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MyContractStorageLocation =
        0x...; // Compute this value for your contract name

    function _getMyContractStorage() private pure returns (MyContractStorage storage $) {
        assembly {
            $.slot := MyContractStorageLocation
        }
    }

    // ---------- Initializer ------------ //
    function initialize(address _upgrader, address[] memory _admins) external initializer {
        require(_upgrader != address(0), "MyContract: upgrader is the zero address");

        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(UPGRADER_ROLE, _upgrader);
        for (uint256 i; i < _admins.length; i++) {
            require(_admins[i] != address(0), "MyContract: admin address cannot be zero");
            _grantRole(DEFAULT_ADMIN_ROLE, _admins[i]);
        }
    }

    // ---------- Modifiers ------------ //
    modifier onlyRoleOrAdmin(bytes32 role) {
        if (!hasRole(role, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert UnauthorizedUser(msg.sender);
        }
        _;
    }

    // ---------- Upgrade ------------ //
    function _authorizeUpgrade(address) internal virtual override onlyRole(UPGRADER_ROLE) {}

    function version() public pure virtual returns (string memory) {
        return "1";
    }
}
```

Key patterns:
- **`_disableInitializers()`** in constructor — prevents implementation contract from being initialized directly
- **`UPGRADER_ROLE`** — separates upgrade authority from admin
- **Namespaced storage** — each contract gets a unique storage slot, avoids collisions
- **`version()`** — returns current version string, used to verify upgrades succeeded
- **`onlyRoleOrAdmin`** — convenience modifier for functions that can be called by a specific role OR admin

### ERC1967 Proxy Contract

Minimal UUPS-compatible proxy. All upgradeable contracts are deployed behind this proxy. Copy as-is.

```solidity
// SPDX-License-Identifier: MIT
// Forked from OpenZeppelin Contracts v5.0.0 (proxy/ERC1967/ERC1967Proxy.sol)
pragma solidity 0.8.20;

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/// @dev UUPS-compatible ERC1967 proxy.
/// Constructor deploys the implementation and optionally calls an initializer via delegatecall.
// solc-ignore-next-line missing-receive
contract VeChainProxy is Proxy {
    constructor(address implementation, bytes memory _data) payable {
        ERC1967Utils.upgradeToAndCall(implementation, _data);
    }

    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
```

The proxy stores the implementation address in the ERC1967 slot (`0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`). Upgrades happen via `upgradeToAndCall()` on the implementation contract (UUPS pattern — upgrade logic lives in the implementation, not the proxy).

## Solidity Libraries

**Always prefer libraries** to keep contracts maintainable and under the 24KB contract size limit. Extract reusable or isolatable logic into libraries early.

### When to Use Libraries

- **Contract size**: Near the 24KB limit (check with `npx hardhat compile`)
- **Reuse**: Logic shared across contracts or that can be isolated
- **Readability**: Split large contracts into a main contract plus focused "Utils" libraries

### Two Kinds of Libraries

#### A) Storage-types library (not deployed)

Holds storage structs and `internal` getters that return `storage` via a fixed slot (ERC-7201). No `external` functions -- compiled into the contract, not deployed separately.

```solidity
// contracts/my-module/libraries/MyModuleStorageTypes.sol
library MyModuleStorageTypes {
    /// @custom:storage-location erc7201:mymodule.storage.main
    struct MainStorage {
        mapping(bytes32 => uint256) values;
        uint256 counter;
    }

    bytes32 private constant MainStorageLocation =
        0x...; // keccak256(abi.encode(uint256(keccak256("mymodule.storage.main")) - 1)) & ~bytes32(uint256(0xff))

    function _getMainStorage() internal pure returns (MainStorage storage s) {
        bytes32 location = MainStorageLocation;
        assembly { s.slot := location }
    }
}
```

#### B) Utils libraries (deployed and linked)

Contain `external` functions with real logic. Read/write the same storage as the main contract via the storage-types library. Deployed separately; main contract calls them as `LibraryName.functionName(...)`.

```solidity
// contracts/my-module/libraries/ValidationUtils.sol
library ValidationUtils {
    error InvalidInput(bytes32 id);

    function validate(bytes32 id) external view returns (bool) {
        MyModuleStorageTypes.MainStorage storage s = MyModuleStorageTypes._getMainStorage();
        if (s.values[id] == 0) revert InvalidInput(id);
        return true;
    }
}
```

### Project Layout

```
contracts/
├── my-module/
│   ├── MyModule.sol                    # Main contract (thin facade)
│   └── libraries/
│       ├── MyModuleStorageTypes.sol     # Storage structs + internal slot getters (not deployed)
│       ├── ValidationUtils.sol         # External logic library (deployed)
│       └── ProcessingUtils.sol         # External logic library (deployed)
├── libraries/
│   └── SharedDataTypes.sol             # Types shared across modules
└── interfaces/
    └── IMyModule.sol
```

### Main Contract Pattern

```solidity
import "./libraries/MyModuleStorageTypes.sol";
import "./libraries/ValidationUtils.sol";
import "./libraries/ProcessingUtils.sol";

contract MyModule is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    using MyModuleStorageTypes for *;

    function doSomething(bytes32 id) external onlyRole(OPERATOR_ROLE) {
        ValidationUtils.validate(id);       // Delegated to library
        ProcessingUtils.process(id);        // Delegated to library
    }
}
```

- Access control and modifiers stay in the main contract
- Libraries only get storage and do the logic
- No `using` for deployed (external) libraries -- call directly

### Deployment with Library Linking

Deploy Utils libraries first, then link them when deploying the main contract:

```typescript
// scripts/libraries/myModuleLibraries.ts
export async function deployMyModuleLibraries() {
  const ValidationUtils = await ethers.deployContract('ValidationUtils');
  await ValidationUtils.waitForDeployment();

  const ProcessingUtils = await ethers.deployContract('ProcessingUtils');
  await ProcessingUtils.waitForDeployment();

  return {
    ValidationUtils: await ValidationUtils.getAddress(),
    ProcessingUtils: await ProcessingUtils.getAddress(),
  };
}

// scripts/deploy.ts
const libs = await deployMyModuleLibraries();

const MyModule = await ethers.getContractFactory('MyModule', {
  libraries: {
    ValidationUtils: libs.ValidationUtils,
    ProcessingUtils: libs.ProcessingUtils,
  },
});
```

Use the **same** `libraries` object for both deploy and upgrade of the implementation.

### Upgrade Rules

- **Redeploy all libraries** when upgrading the main contract version
- Pass the new library addresses in `options.libraries` to `upgradeProxy`
- For upgrade tests, keep deprecated contract/library versions under `contracts/deprecated/V{N}/` so you can deploy V(N-1) and upgrade to V(N)

### Storage Safety

- **Never** change order, remove, or change types of existing storage variables
- Only **append** new fields at the end of storage structs
- This applies to both the storage-types library and the main contract

### Library Style

- Use **custom errors** (e.g., `error NonexistentItem(bytes32 id);`)
- Emit **events** in the library when the event is part of the module's API
- Use NatSpec (`@title`, `@dev`) on each library and public/external functions
- Keep imports minimal and directional (e.g., `../../interfaces/`, `./StorageTypes.sol`)

### Quick Checklist for Adding a New Utils Library

1. Create `contracts/<module>/libraries/<Name>Utils.sol` with `external` functions
2. Access storage only via the module's storage-types library
3. Add to the module's library deployment script and include in the returned object
4. Add library name + address to the `libraries` map for `getContractFactory`
5. Import in the main contract and call `NewUtils.functionName(...)`
6. Do not add or change storage layout in the main contract -- keep new storage in the storage-types library, append only

---

## Deployment

### Simple (non-upgradeable) Deployment
```typescript
import { ethers } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying with:', deployer.address);

  const MyToken = await ethers.deployContract('MyToken', [1_000_000]);
  await MyToken.waitForDeployment();
  console.log('MyToken deployed to:', await MyToken.getAddress());
}

main().catch(console.error);
```

### Proxy Deployment Helpers (`scripts/helpers/upgrades.ts`)

For upgradeable contracts, **always use the proxy helpers**. These deploy the implementation + proxy together and handle initialization.

Required dependencies:
```bash
npm install @openzeppelin/contracts@5.0.2 @openzeppelin/contracts-upgradeable@5.0.2 @openzeppelin/upgrades-core
```

Key functions:

```typescript
import { deployProxy, upgradeProxy, deployProxyOnly, initializeProxy } from "./helpers/upgrades"

// Deploy proxy + implementation + initialize in one step
const contract = await deployProxy("MyContract", [upgraderAddr, [adminAddr]])

// Deploy proxy without initialization (for contracts needing multi-step init)
const proxyAddress = await deployProxyOnly("MyContract")
await initializeProxy(proxyAddress, "MyContract", [upgraderAddr, [adminAddr]])

// Upgrade existing proxy to new implementation
const upgraded = await upgradeProxy(
  "MyContractV1",     // previous version contract name
  "MyContract",       // new version contract name (latest = no suffix)
  proxyAddress,
  [reinitArg1],       // args for initializeV{N}
  { version: 2 }      // triggers initializeV2
)
```

How `deployProxy` works internally:
1. Deploys the implementation contract
2. Deploys `VeChainProxy` pointing to the implementation
3. Encodes and calls the `initialize` (or `initializeV{N}`) function via delegatecall
4. Verifies the proxy's implementation address matches (via `@openzeppelin/upgrades-core`)
5. Returns a contract instance attached to the proxy address

How `upgradeProxy` works internally:
1. Deploys the new implementation contract
2. Calls `upgradeToAndCall()` on the existing proxy (via the previous version's ABI)
3. If args provided, encodes `initializeV{N}` and passes as calldata
4. Verifies the new implementation address
5. Returns a contract instance with the new ABI attached to the proxy

### Deploy Commands
```bash
# Local (Thor Solo)
npx hardhat run scripts/deploy/deploy.ts --network vechain_solo

# Testnet
npx hardhat run scripts/deploy/deploy.ts --network vechain_testnet

# Mainnet
npx hardhat run scripts/deploy/deploy.ts --network vechain_mainnet
```

### Deploy with Fee Delegation

Add a `delegate` config to the network. See the **vechain-core** skill (`references/fee-delegation.md`) for full setup.

---

## Upgrade Infrastructure

### Version Pattern

When upgrading a contract to a new version:

1. Copy current contract to `contracts/deprecated/V{N}/` before modifying
2. Increment `version()` return value in the new version
3. Add `initializeV{N}` with `reinitializer(N)` for any new state setup
4. Create upgrade script in `scripts/upgrade/upgrades/{contract}/{contract}-v{N}.ts`
5. Register in `scripts/upgrade/upgradesConfig.ts` for CLI selection
6. Update `scripts/deploy/deploy.ts` with new deployment logic
7. Update `test/helpers/deploy.ts` to mirror deployment changes
8. Create upgrade test: `test/{contract}/v{N}-upgrade.test.ts`

### Reinitializer Pattern

Use `reinitializer(N)` for upgrade initialization. The `N` must match the version number and can only be called once.

```solidity
function initializeV2(address newParam) public reinitializer(2) {
    MyContractStorage storage $ = _getMyContractStorage();
    $.newField = newParam;
}

function initializeV3(uint256 threshold) public reinitializer(3) {
    MyContractStorage storage $ = _getMyContractStorage();
    $.threshold = threshold;
}
```

The proxy helpers automatically find the right initializer: `getInitializerData` looks for `initializeV{N}` when `version` is specified, or `initialize` for V1.

### Keeping Deprecated Versions

Deprecated versions in `contracts/deprecated/V{N}/` enable upgrade tests that verify no storage corruption:

```typescript
// Deploy previous version
const v1 = await deployProxy("MyContractV1", [upgrader, [admin]])
await v1.setValue(42)

// Upgrade to new version
const v2 = await upgradeProxy("MyContractV1", "MyContract", await v1.getAddress(), [newParam], { version: 2 })

// Verify state preserved
expect(await v2.value()).to.equal(42)
// Verify new functionality
expect(await v2.version()).to.equal("2")
```

### CRITICAL: Upgrade Test Version Mismatch

When writing upgrade tests, always use **explicit version names** for intermediate upgrades:

```typescript
// WRONG: "MyContract" refers to the LATEST version (now V5), not V2
const v2 = await upgradeProxy("MyContractV1", "MyContract", ...) // Skips V2/V3/V4!

// CORRECT: explicit version for intermediate upgrades
const v2 = await upgradeProxy("MyContractV1", "MyContractV2", ...)
const v3 = await upgradeProxy("MyContractV2", "MyContractV3", ...)

// Only use bare name when upgrading TO the latest version
const latest = await upgradeProxy("MyContractV4", "MyContract", ...)
```

### CLI Upgrade System

Interactive CLI for selecting and running upgrades:

```bash
npx hardhat run scripts/upgrade/select-and-upgrade.ts --network vechain_solo
```

Reads from `upgradesConfig.ts` — a registry mapping contract names to available versions:

```typescript
// scripts/upgrade/upgradesConfig.ts
export const upgradeConfig: Record<string, UpgradeContract> = {
  MyContract: {
    name: "my-contract",
    configAddressField: "myContract",    // key in config.contracts
    versions: ["v2", "v3"],
    descriptions: {
      v2: "Add threshold configuration",
      v3: "Add batch processing support",
    },
  },
}
```

### Upgrade Script Template

```typescript
// scripts/upgrade/upgrades/my-contract/my-contract-v2.ts
import { getConfig } from "@repo/config"
import { upgradeProxy } from "../../helpers/upgrades"
import { ethers } from "hardhat"

async function main() {
  const config = getConfig()

  const contract = await ethers.getContractAt("MyContract", config.contracts.myContract)
  console.log("Current version:", await contract.version())

  const upgraded = await upgradeProxy(
    "MyContractV1",
    "MyContract",
    config.contracts.myContract,
    [newParam],       // reinitializer args
    { version: 2 },
  )

  const newVersion = await upgraded.version()
  if (parseInt(newVersion) !== 2) throw new Error("Upgrade failed")
  console.log("Upgraded to version:", newVersion)
}

main().catch(console.error)
```

### Deploy + Test Sync

When upgrading contracts, **always update both**:
1. **`scripts/deploy/deploy.ts`** — production deployment (auto-runs via `yarn dev` if contracts not deployed)
2. **`test/helpers/deploy.ts`** — test fixture deployment (used by all contract tests)

These files must stay aligned — changes to one usually require changes to the other.

### Adding a New Contract Checklist

When adding a completely new contract:
1. Create the contract following the BaseUpgradeable template
2. Add to `scripts/deploy/deploy.ts`
3. Add to `test/helpers/deploy.ts`
4. Update `packages/config` — add address field to `AppConfig` type
5. Update `packages/config/scripts/generateMockLocalConfig.mjs` — add mock address
6. Update `scripts/checkContractsDeployment.ts` — add deployment check

---

## Code Style

### NatSpec Documentation

All public/external functions require NatSpec:

```solidity
/// @notice Brief description of what the function does
/// @dev Implementation details, edge cases, or important notes
/// @param paramName Description of the parameter
/// @return Description of the return value
function myFunction(uint256 paramName) external returns (uint256) {
```

### Custom Errors

Use custom errors instead of `require` strings (more gas efficient):

```solidity
error InvalidAmount(uint256 provided, uint256 minimum);
error UnauthorizedUser(address user);

function deposit(uint256 amount) external {
    if (amount < MIN_AMOUNT) revert InvalidAmount(amount, MIN_AMOUNT);
}
```

### Events

Emit events for all state changes:

```solidity
event ValueUpdated(address indexed user, uint256 oldValue, uint256 newValue);

function setValue(uint256 _value) external {
    uint256 old = _getStorage().value;
    _getStorage().value = _value;
    emit ValueUpdated(msg.sender, old, _value);
}
```

---

## Slither Static Analysis

Slither can be run in CI on contract changes. Configure false positive suppressions:

```json
{
  "suppressions": [
    {
      "check": "reentrancy-eth",
      "file": "contracts/MyContract.sol",
      "function": "myFunction(uint256)",
      "reason": "CEI pattern followed, nonReentrant guard present"
    }
  ]
}
```

## Contract Interaction with SDK

### Read from contract
```typescript
import { ThorClient } from '@vechain/sdk-network';

const thorClient = ThorClient.at('https://testnet.vechain.org');
const contract = thorClient.contracts.load(contractAddress, contractABI);

const balance = await contract.read.balanceOf(someAddress);
const name = await contract.read.name();
```

### Write to contract (backend/scripts)
```typescript
import { ThorClient, VeChainProvider, ProviderInternalBaseWallet } from '@vechain/sdk-network';

const thorClient = ThorClient.at('https://testnet.vechain.org');
const wallet = new ProviderInternalBaseWallet([
  { privateKey: HexUInt.of(privateKey).bytes, address: senderAddress }
]);
const provider = new VeChainProvider(thorClient, wallet);
const signer = await provider.getSigner(senderAddress);

const contract = thorClient.contracts.load(contractAddress, contractABI, signer);
const tx = await contract.transact.transfer(recipientAddress, amount);
```

### Batch reads with multi-clause
```typescript
const results = await thorClient.contracts.executeMultipleClausesCall([
  contract.clause.totalSupply(),
  contract.clause.name(),
  contract.clause.symbol(),
  contract.clause.decimals()
]);
```

## VeChain-Specific Considerations

### Dual Token Model
- **VET**: Value transfer token. Transfer with `Clause.transferVET()`.
- **VTHO**: Gas token. Generated by staking VET. Transfer with `Clause.transferVTHOToken()`.
- VTHO contract address: `0x0000000000000000000000000000456E65726779`

### Built-in Contracts
VeChainThor has several built-in contracts at genesis:
- **Authority**: `0x0000000000000000000000417574686f72697479` - Authority node management
- **Energy (VTHO)**: `0x0000000000000000000000000000456E65726779` - VTHO token
- **Params**: `0x0000000000000000000000000000506172616d73` - Network parameters
- **Executor**: `0x0000000000000000000000004578656375746f72` - On-chain governance
- **Extension**: `0x0000000000000000000000457874656e73696f6e` - Extended functionality

### Block Time
VeChainThor produces blocks every ~10 seconds (vs Ethereum's ~12 seconds). With Thor Solo `--on-demand`, blocks are produced only when transactions are pending.

## Security Best Practices

### Input Validation
- Use `require` statements for all external input validation
- Use OpenZeppelin's `ReentrancyGuard` for functions that transfer value
- Validate addresses are non-zero with `require(addr != address(0))`

### Access Control
- Prefer OpenZeppelin's `AccessControl` over custom role management
- Use `Ownable2Step` over `Ownable` for safer ownership transfers
- Never use `tx.origin` for authorization

### Common Gotchas
- **EVM version**: Always use `paris`. Newer opcodes will cause deployment failures.
- **Gas estimation**: Use `gas: 'auto'` in Hardhat config for VeChain's gas model.
- **Block timestamps**: VeChain has ~10s block time; do not rely on sub-second precision.
- **Chain ID**: Mainnet is `0x4a` (74), testnet is `0x27` (39).
