# Monorepo Templates

Turborepo monorepo with `apps/frontend` (Next.js) and `packages/contracts` (Hardhat + Solidity).
Source files from `shared.md` go under `apps/frontend/src/`.

## Directory structure

```text
{{PROJECT_NAME}}/
├── .env.example
├── .github/workflows/deploy.yml
├── .gitignore
├── .nvmrc
├── Makefile
├── package.json
├── turbo.json
├── apps/
│   └── frontend/
│       ├── .eslintrc.json
│       ├── next.config.js
│       ├── package.json
│       ├── tsconfig.json
│       └── src/
│           └── (all shared.md src/ files here)
├── packages/
│   ├── config/
│   │   ├── index.ts
│   │   ├── local.ts              ← git-ignored, auto-generated
│   │   ├── testnet.ts
│   │   ├── mainnet.ts
│   │   ├── package.json
│   │   └── scripts/
│   │       └── generateMockLocalConfig.mjs
│   ├── contracts/
│   │   ├── .gitignore
│   │   ├── docker-compose.yaml
│   │   ├── contracts/
│   │   │   ├── HelloWorld.sol          ← UUPS upgradeable
│   │   │   └── VeChainProxy.sol        ← ERC1967 proxy
│   │   ├── hardhat.config.ts
│   │   ├── package.json
│   │   ├── scripts/
│   │   │   ├── helpers/
│   │   │   │   └── upgrades.ts         ← deploy/upgrade proxy helpers
│   │   │   ├── deploy/
│   │   │   │   └── deploy.ts           ← production deployment
│   │   │   ├── upgrade/
│   │   │   │   ├── select-and-upgrade.ts
│   │   │   │   ├── upgradesConfig.ts
│   │   │   │   └── upgrades/           ← per-contract upgrade scripts
│   │   │   └── checkContractsDeployment.ts
│   │   ├── test/
│   │   │   └── HelloWorld.test.ts
│   │   └── tsconfig.json
│   ├── eslint-config/
│   │   ├── library.js
│   │   ├── next.js
│   │   └── package.json
│   └── typescript-config/
│       ├── base.json
│       ├── nextjs.json
│       └── package.json
```

## Root files

### `package.json`

```json
{
  "name": "{{PROJECT_NAME}}",
  "private": true,
  "scripts": {
    "dev": "yarn && dotenv -v NEXT_PUBLIC_APP_ENV=local -e .env -- turbo dev",
    "dev:testnet": "yarn && dotenv -v NEXT_PUBLIC_APP_ENV=testnet -e .env -- turbo dev",
    "dev:mainnet": "yarn && dotenv -v NEXT_PUBLIC_APP_ENV=mainnet -e .env -- turbo dev",
    "build": "turbo build",
    "lint": "turbo lint",
    "typecheck": "turbo typecheck",
    "contracts:compile": "turbo compile --filter=@{{PROJECT_NAME}}/contracts",
    "contracts:test": "turbo test --filter=@{{PROJECT_NAME}}/contracts",
    "contracts:generate-docs": "turbo generate-docs --filter=@{{PROJECT_NAME}}/contracts",
    "contracts:coverage": "turbo coverage --filter=@{{PROJECT_NAME}}/contracts",
    "contracts:size": "turbo size --filter=@{{PROJECT_NAME}}/contracts",
    "solo-up": "make solo-up",
    "solo-down": "make solo-down",
    "clean": "turbo clean && rm -rf node_modules"
  },
  "dependencies": {
    "turbo": "^2.5.0"
  },
  "devDependencies": {
    "dotenv-cli": "^7.4.0",
    "prettier": "^3.3.0"
  },
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "engines": {
    "node": "20.x.x"
  },
  "packageManager": "yarn@1.22.22"
}
```

### `turbo.json`

The turbo pipeline ensures contracts are compiled and deployed before the frontend starts. Each `dev:<env>` variant runs the matching `check-contracts-deployment:<env>` against the correct network.

**Flow:** `dev` → `setup-contracts` → `compile` + `check-contracts-deployment` → `check-or-generate-local-config`

- `check-or-generate-local-config` runs first to ensure `packages/config/local.ts` exists (generates mock if missing)
- `compile` depends on config being available (Hardhat imports config)
- `check-contracts-deployment` runs after compile — checks if contracts are deployed, deploys if not, writes addresses to the matching config file
- `setup-contracts` orchestrates compile + deployment check
- `dev` depends on `setup-contracts` completing
- `dev:testnet` / `dev:mainnet` follow the same flow but target their respective networks

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalEnv": ["NEXT_PUBLIC_APP_ENV", "NEXT_PUBLIC_BASE_PATH", "MNEMONIC"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**", "out/**"]
    },
    "@{{PROJECT_NAME}}/contracts#build": {
      "cache": true,
      "dependsOn": ["@{{PROJECT_NAME}}/config#check-or-generate-local-config"],
      "outputs": ["artifacts/**", "typechain-types/**", "cache/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true,
      "dependsOn": ["^setup-contracts"]
    },
    "dev:testnet": {
      "cache": false,
      "persistent": true,
      "dependsOn": ["^setup-contracts:testnet"]
    },
    "dev:mainnet": {
      "cache": false,
      "persistent": true,
      "dependsOn": ["^setup-contracts:mainnet"]
    },
    "setup-contracts": {
      "cache": false,
      "dependsOn": ["^compile", "@{{PROJECT_NAME}}/contracts#check-contracts-deployment"]
    },
    "setup-contracts:testnet": {
      "cache": false,
      "dependsOn": ["^compile", "@{{PROJECT_NAME}}/contracts#check-contracts-deployment:testnet"]
    },
    "setup-contracts:mainnet": {
      "cache": false,
      "dependsOn": ["^compile", "@{{PROJECT_NAME}}/contracts#check-contracts-deployment:mainnet"]
    },
    "@{{PROJECT_NAME}}/config#check-or-generate-local-config": {
      "cache": false
    },
    "compile": {
      "cache": true,
      "dependsOn": ["@{{PROJECT_NAME}}/config#check-or-generate-local-config"],
      "outputs": ["artifacts/**", "typechain-types/**", "cache/**"]
    },
    "@{{PROJECT_NAME}}/contracts#check-contracts-deployment": {
      "cache": false,
      "dependsOn": ["^compile", "@{{PROJECT_NAME}}/config#check-or-generate-local-config"]
    },
    "@{{PROJECT_NAME}}/contracts#check-contracts-deployment:testnet": {
      "cache": false,
      "dependsOn": ["^compile", "@{{PROJECT_NAME}}/config#check-or-generate-local-config"]
    },
    "@{{PROJECT_NAME}}/contracts#check-contracts-deployment:mainnet": {
      "cache": false,
      "dependsOn": ["^compile", "@{{PROJECT_NAME}}/config#check-or-generate-local-config"]
    },
    "lint": {
      "cache": false
    },
    "typecheck": {
      "cache": false
    },
    "test": {
      "cache": false,
      "dependsOn": ["^compile", "@{{PROJECT_NAME}}/config#check-or-generate-local-config"]
    },
    "clean": {
      "cache": false
    }
  }
}
```

### `.gitignore`

```text
node_modules/
.next/
out/
dist/
.env
.env.local
*.tsbuildinfo
next-env.d.ts
artifacts/
cache/
typechain-types/
coverage/

# Auto-generated local config (each dev's solo deployment has different addresses)
packages/config/local.ts
```

### `.nvmrc`

```text
20
```

### `.env.example`

Root env file used by both frontend and contracts. Copy to `.env` before running.

```text
# ---- Wallet ----
# Solo node mnemonic (pre-funded, for local dev only)
MNEMONIC="denial kitchen pet squirrel other broom bar gas better priority spoil cross"

# ---- Frontend ----
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=
NEXT_PUBLIC_BASE_PATH=
```

- `MNEMONIC` — used by Hardhat for contract deployment. The default solo mnemonic has pre-funded accounts. For testnet/mainnet, replace with your own.
- `NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID` — get one from https://cloud.walletconnect.com
- `NEXT_PUBLIC_BASE_PATH` — set to `/<repo-name>` for GitHub Pages, leave empty for custom domains or local dev.

### `Makefile`

Convenience targets for managing the Thor solo node (requires Docker).

```makefile
SHELL := /bin/bash

help:
    @egrep -h '\s#@\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?#@ "}; {printf "\033[36m  %-30s\033[0m %s\n", $$1, $$2}'

# Thor solo
solo-up: #@ Start Thor solo
    docker compose -f packages/contracts/docker-compose.yaml up -d --wait
solo-down: #@ Stop Thor solo
    docker compose -f packages/contracts/docker-compose.yaml down
solo-clean: #@ Clean Thor solo (removes volumes)
    docker compose -f packages/contracts/docker-compose.yaml down -v --remove-orphans
```

- `make solo-up` — start Thor solo in the background, wait until healthy
- `make solo-down` — stop Thor solo
- `make solo-clean` — stop and remove all data (fresh chain next start)

## `apps/frontend/`

### `package.json`

```json
{
  "name": "@{{PROJECT_NAME}}/frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev --turbo",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@chakra-ui/react": "3.30.0",
    "@emotion/react": "^11.14.0",
    "@tanstack/react-query": "^5.64.2",
    "@vechain/vechain-kit": "latest",
    "next": "14.2.25",
    "next-themes": "^0.4.6",
    "react": "^18",
    "react-dom": "^18",
    "react-icons": "^5.5.0"
  },
  "devDependencies": {
    "@{{PROJECT_NAME}}/eslint-config": "*",
    "@{{PROJECT_NAME}}/typescript-config": "*",
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "eslint": "^8",
    "eslint-config-next": "14.2.25",
    "typescript": "^5"
  }
}
```

### `next.config.js`

Same as standalone — see `standalone.md`.

```javascript
/** @type {import('next').NextConfig} */
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? ""

const nextConfig = {
  output: "export",
  basePath: basePath || undefined,
  assetPrefix: basePath ? `${basePath}/` : undefined,
  reactStrictMode: true,
  typescript: { ignoreBuildErrors: false },
  eslint: { ignoreDuringBuilds: true },
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
      }
    }
    return config
  },
}

module.exports = nextConfig
```

### `tsconfig.json`

```json
{
  "extends": "@{{PROJECT_NAME}}/typescript-config/nextjs.json",
  "compilerOptions": {
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "noUncheckedIndexedAccess": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": [".next", "node_modules", "out"]
}
```

### `.eslintrc.json`

```json
{
  "extends": ["@{{PROJECT_NAME}}/eslint-config/next"]
}
```

The frontend reads env vars from the root `.env` file (Turborepo propagates `globalEnv` vars). No separate frontend `.env.example` is needed in monorepo mode.

## `packages/typescript-config/`

### `package.json`

```json
{
  "name": "@{{PROJECT_NAME}}/typescript-config",
  "version": "0.0.0",
  "private": true
}
```

### `base.json`

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "declaration": true,
    "declarationMap": true,
    "esModuleInterop": true,
    "incremental": false,
    "isolatedModules": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "NodeNext",
    "moduleDetection": "force",
    "moduleResolution": "NodeNext",
    "noUncheckedIndexedAccess": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "strict": true,
    "target": "ES2022"
  }
}
```

### `nextjs.json`

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "extends": "./base.json",
  "compilerOptions": {
    "plugins": [{ "name": "next" }],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowJs": true,
    "jsx": "preserve",
    "noEmit": true
  }
}
```

## `packages/eslint-config/`

### `package.json`

```json
{
  "name": "@{{PROJECT_NAME}}/eslint-config",
  "version": "0.0.0",
  "private": true,
  "files": ["library.js", "next.js"],
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^6.11.0",
    "@typescript-eslint/parser": "^6.11.0",
    "@vercel/style-guide": "^5.1.0",
    "eslint-config-prettier": "^9.0.0",
    "eslint-config-turbo": "^2.5.5",
    "eslint-plugin-only-warn": "^1.1.0",
    "typescript": "^5"
  }
}
```

### `library.js`

```javascript
const { resolve } = require("node:path")
const project = resolve(process.cwd(), "tsconfig.json")

module.exports = {
  extends: ["eslint:recommended", "prettier"],
  plugins: ["only-warn"],
  globals: { React: true, JSX: true },
  env: { node: true },
  settings: { "import/resolver": { typescript: { project } } },
  ignorePatterns: [".*.js", "node_modules/", "dist/"],
  overrides: [{ files: ["*.js?(x)", "*.ts?(x)"] }],
}
```

### `next.js`

```javascript
const { resolve } = require("node:path")
const project = resolve(process.cwd(), "tsconfig.json")

module.exports = {
  extends: [
    "eslint:recommended",
    "prettier",
    require.resolve("@vercel/style-guide/eslint/next"),
    "plugin:turbo/recommended",
  ],
  globals: { React: true, JSX: true },
  env: { node: true, browser: true },
  plugins: ["only-warn"],
  settings: { "import/resolver": { typescript: { project } } },
  ignorePatterns: [".*.js", "node_modules/"],
  overrides: [{ files: ["*.js?(x)", "*.ts?(x)"] }],
}
```

## `packages/config/`

Central configuration package. Each environment has its own file with contract addresses and network settings.
`local.ts` is git-ignored and auto-generated — each developer's solo deployment produces different addresses.

### How it works

1. `check-or-generate-local-config` (turbo task) runs `generateMockLocalConfig.mjs` — creates `local.ts` with placeholder addresses if it doesn't exist
2. Contracts compile using these placeholder addresses (Hardhat imports `getConfig()`)
3. `check-contracts-deployment` checks if contracts are actually deployed on solo — if not, deploys them and overwrites `local.ts` with real addresses
4. Frontend and tests use `getConfig()` which routes to the correct env file based on `NEXT_PUBLIC_APP_ENV`

### `package.json`

```json
{
  "name": "@{{PROJECT_NAME}}/config",
  "version": "0.0.0",
  "private": true,
  "exports": {
    ".": "./index.ts",
    "./local": "./local.ts",
    "./testnet": "./testnet.ts",
    "./mainnet": "./mainnet.ts"
  },
  "scripts": {
    "check-or-generate-local-config": "ts-node ./scripts/generateMockLocalConfig.mjs"
  },
  "devDependencies": {
    "ts-node": "^10.9.2"
  }
}
```

### `index.ts`

```typescript
import localConfig from "./local"
import testnetConfig from "./testnet"
import mainnetConfig from "./mainnet"

export type AppConfig = {
  environment: string
  nodeUrl: string
  network: {
    id: string
    name: string
    urls: string[]
    explorerUrl: string
    genesis: {
      id: string
    }
  }
  contracts: {
    helloWorld: string
  }
}

export const AppEnv = {
  LOCAL: "local",
  TESTNET: "testnet",
  MAINNET: "mainnet",
} as const

export type EnvConfig = (typeof AppEnv)[keyof typeof AppEnv]

export const getConfig = (env?: string): AppConfig => {
  const appEnv = env || process.env.NEXT_PUBLIC_APP_ENV
  if (!appEnv) throw new Error("NEXT_PUBLIC_APP_ENV must be set or env must be passed to getConfig()")

  switch (appEnv) {
    case AppEnv.LOCAL:
      return localConfig
    case AppEnv.TESTNET:
      return testnetConfig
    case AppEnv.MAINNET:
      return mainnetConfig
    default:
      throw new Error(`Unsupported NEXT_PUBLIC_APP_ENV: ${appEnv}`)
  }
}
```

### `testnet.ts`

```typescript
import { AppConfig } from "."

const config: AppConfig = {
  environment: "testnet",
  nodeUrl: "https://testnet.vechain.org",
  network: {
    id: "testnet",
    name: "testnet",
    urls: ["https://testnet.vechain.org"],
    explorerUrl: "https://explore-testnet.vechain.org",
    genesis: {
      id: "0x000000000b2bce3c70bc649a02749e8687721b09ed2e15997f466536b20bb127",
    },
  },
  contracts: {
    helloWorld: "", // Deploy and fill in your testnet address
  },
}

export default config
```

### `mainnet.ts`

```typescript
import { AppConfig } from "."

const config: AppConfig = {
  environment: "mainnet",
  nodeUrl: "https://mainnet.vechain.org",
  network: {
    id: "mainnet",
    name: "mainnet",
    urls: ["https://mainnet.vechain.org"],
    explorerUrl: "https://explore.vechain.org",
    genesis: {
      id: "0x00000000851caf3cfdb6e899cf5958bfb1ac3413d346d43539627e6be7ec1b4a",
    },
  },
  contracts: {
    helloWorld: "", // Deploy and fill in your mainnet address
  },
}

export default config
```

### `scripts/generateMockLocalConfig.mjs`

Generates a mock `local.ts` with placeholder addresses so compilation can proceed before contracts are deployed.

```typescript
import fs from "fs"
import path from "path"

export const generateMockLocalConfig = () => {
  console.log("Checking if @{{PROJECT_NAME}}/config/local.ts exists...")
  const localConfigPath = path.resolve("./local.ts")
  if (fs.existsSync(localConfigPath)) {
    console.log(`${localConfigPath} exists, skipping...`)
    return
  }

  console.log(`${localConfigPath} does not exist, generating mock...`)
  const toWrite = `import { AppConfig } from "."
const config: AppConfig = {
  environment: "local",
  nodeUrl: "http://localhost:8669",
  network: {
    id: "solo",
    name: "solo",
    urls: ["http://localhost:8669"],
    explorerUrl: "http://localhost:8669",
    genesis: {
      id: "0x00000000c05a20fbca2bf6ae3affba6af4a74b800b585bf7a4988aba7aea69f6",
    },
  },
  contracts: {
    helloWorld: "0x0000000000000000000000000000000000000000",
  },
}
export default config
`

  console.log(`Writing mock config file to ${localConfigPath}`)
  fs.writeFileSync(localConfigPath, toWrite)
  console.log("Done!")
}

generateMockLocalConfig()
```

## `packages/contracts/`

### `package.json`

```json
{
  "name": "@{{PROJECT_NAME}}/contracts",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "compile": "hardhat compile",
    "build": "hardhat compile",
    "test": "hardhat test --network hardhat",
    "check-contracts-deployment": "hardhat run scripts/checkContractsDeployment.ts --network vechain_solo",
    "check-contracts-deployment:testnet": "hardhat run scripts/checkContractsDeployment.ts --network vechain_testnet",
    "check-contracts-deployment:mainnet": "hardhat run scripts/checkContractsDeployment.ts --network vechain_mainnet",
    "setup-contracts": "echo 'Setup complete'",
    "setup-contracts:testnet": "echo 'Setup complete'",
    "setup-contracts:mainnet": "echo 'Setup complete'",
    "deploy:local": "hardhat run scripts/deploy/deploy.ts --network vechain_solo",
    "deploy:testnet": "hardhat run scripts/deploy/deploy.ts --network vechain_testnet",
    "deploy:mainnet": "hardhat run scripts/deploy/deploy.ts --network vechain_mainnet",
    "upgrade:local": "hardhat run scripts/upgrade/select-and-upgrade.ts --network vechain_solo",
    "upgrade:testnet": "hardhat run scripts/upgrade/select-and-upgrade.ts --network vechain_testnet",
    "upgrade:mainnet": "hardhat run scripts/upgrade/select-and-upgrade.ts --network vechain_mainnet",
    "generate-docs": "hardhat docgen",
    "coverage": "hardhat coverage",
    "size": "hardhat size-contracts",
    "clean": "hardhat clean"
  },
  "dependencies": {
    "@{{PROJECT_NAME}}/config": "*",
    "@openzeppelin/contracts": "5.0.2",
    "@openzeppelin/contracts-upgradeable": "5.0.2",
    "@openzeppelin/upgrades-core": "^1.40.0"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^5.0.0",
    "@vechain/sdk-core": "latest",
    "@vechain/sdk-hardhat-plugin": "latest",
    "hardhat": "^2.22.0",
    "hardhat-contract-sizer": "^2.10.0",
    "hardhat-ignore-warnings": "^0.2.12",
    "inquirer": "^9.0.0",
    "solidity-coverage": "^0.8.14",
    "solidity-docgen": "^0.6.0-beta.36",
    "typescript": "^5"
  }
}
```

### `hardhat.config.ts`

```typescript
import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@vechain/sdk-hardhat-plugin"
import "hardhat-contract-sizer"
import "hardhat-ignore-warnings"
import "solidity-coverage"
import "solidity-docgen"
import { EnvConfig, getConfig } from "@{{PROJECT_NAME}}/config"
import { HDKey } from "@vechain/sdk-core"

const SOLO_MNEMONIC = "denial kitchen pet squirrel other broom bar gas better priority spoil cross"

const getSoloUrl = () => {
  const url = process.env.NEXT_PUBLIC_APP_ENV
    ? getConfig(process.env.NEXT_PUBLIC_APP_ENV as EnvConfig).network.urls[0]
    : "http://localhost:8669"
  return url
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: { enabled: true, runs: 1 },
          evmVersion: "paris",
        },
      },
    ],
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    except: ["mocks", "deprecated", "interfaces", "test", "templates", "openzeppelin", "libraries"],
  },
  mocha: {
    timeout: 1800000,
  },
  gasReporter: {
    enabled: false,
    excludeContracts: ["mocks", "deprecated", "interfaces", "test", "templates"],
  },
  docgen: {
    pages: "files",
  },
  defaultNetwork: process.env.IS_TEST_COVERAGE ? "hardhat" : "vechain_solo",
  networks: {
    hardhat: {
      chainId: 1337,
      accounts: {
        count: 20,
        accountsBalance: "1000000000000000000000000",
      },
    },
    vechain_solo: {
      url: getSoloUrl(),
      accounts: {
        mnemonic: process.env.MNEMONIC ?? SOLO_MNEMONIC,
        count: 20,
        path: HDKey.VET_DERIVATION_PATH,
        accountsBalance: "1000000000000000000000000",
      },
      gas: 10000000,
    },
    vechain_testnet: {
      url: "https://testnet.vechain.org",
      chainId: 100010,
      accounts: {
        mnemonic: process.env.MNEMONIC ?? "",
        count: 20,
        path: HDKey.VET_DERIVATION_PATH,
      },
      gas: 10000000,
    },
    vechain_mainnet: {
      url: "https://mainnet.vechain.org",
      chainId: 100009,
      accounts: {
        mnemonic: process.env.MNEMONIC ?? "",
        count: 20,
        path: HDKey.VET_DERIVATION_PATH,
      },
      gas: 10000000,
    },
  },
}

export default config
```

### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "moduleResolution": "node",
    "strict": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "declaration": true
  },
  "include": ["hardhat.config.ts", "contracts/**/*.sol", "test/**/*.ts", "scripts/**/*.ts"],
  "exclude": ["node_modules", "dist", "artifacts", "cache"]
}
```

### `contracts/VeChainProxy.sol`

ERC1967 UUPS proxy. Used by the deploy helpers to wrap all upgradeable contracts. Copy as-is.

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

### `contracts/HelloWorld.sol`

UUPS upgradeable starter contract. Follows the pattern from the `smart-contract-development` skill.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract HelloWorld is AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ---------- Storage ------------ //
    struct HelloWorldStorage {
        string greeting;
    }

    // keccak256(abi.encode(uint256(keccak256("storage.HelloWorld")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HelloWorldStorageLocation =
        0x34a15ab0b3484a5fe3296a09e65efabd0e8e42e7718c06ac9bfe421a06379c00;

    function _getHelloWorldStorage() private pure returns (HelloWorldStorage storage $) {
        assembly {
            $.slot := HelloWorldStorageLocation
        }
    }

    // ---------- Initializer ------------ //
    function initialize(address _upgrader, address _admin) external initializer {
        require(_upgrader != address(0), "HelloWorld: upgrader is the zero address");
        require(_admin != address(0), "HelloWorld: admin is the zero address");

        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(UPGRADER_ROLE, _upgrader);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        HelloWorldStorage storage $ = _getHelloWorldStorage();
        $.greeting = "Hello, VeChain!";
    }

    // ---------- Getters ------------ //
    function greeting() external view returns (string memory) {
        return _getHelloWorldStorage().greeting;
    }

    // ---------- Setters ------------ //
    event GreetingChanged(string newGreeting);

    function setGreeting(string calldata _greeting) external {
        _getHelloWorldStorage().greeting = _greeting;
        emit GreetingChanged(_greeting);
    }

    // ---------- Upgrade ------------ //
    function _authorizeUpgrade(address) internal virtual override onlyRole(UPGRADER_ROLE) {}

    function version() public pure virtual returns (string memory) {
        return "1";
    }
}
```

### `test/HelloWorld.test.ts`

```typescript
import { expect } from "chai"
import { ethers } from "hardhat"
import { deployProxy } from "../scripts/helpers/upgrades"
import { HelloWorld } from "../typechain-types"

describe("HelloWorld", function () {
  let contract: HelloWorld

  beforeEach(async function () {
    const [deployer] = await ethers.getSigners()
    contract = (await deployProxy("HelloWorld", [deployer.address, deployer.address])) as unknown as HelloWorld
  })

  it("should return the initial greeting", async function () {
    expect(await contract.greeting()).to.equal("Hello, VeChain!")
  })

  it("should update the greeting", async function () {
    await contract.setGreeting("Hello, World!")
    expect(await contract.greeting()).to.equal("Hello, World!")
  })

  it("should return version 1", async function () {
    expect(await contract.version()).to.equal("1")
  })
})
```

### `scripts/helpers/upgrades.ts`

Core proxy deployment and upgrade helpers. **Copy this file as-is.** All deploy/upgrade scripts and tests depend on it.

Adapted from the VeBetterDAO production codebase. Provides:
- `deployProxy` — deploy implementation + proxy + initialize in one step
- `deployProxyOnly` — deploy proxy without initialization
- `initializeProxy` — initialize an already-deployed proxy
- `upgradeProxy` — deploy new implementation, call `upgradeToAndCall` on existing proxy
- `deployAndUpgrade` — deploy V1 proxy then sequentially upgrade through multiple versions
- `getInitializerData` — encode `initialize` or `initializeV{N}` call

```typescript
import { BaseContract, Contract, Interface } from "ethers"
import { ethers } from "hardhat"
import { getImplementationAddress } from "@openzeppelin/upgrades-core"

export type DeployUpgradeOptions = {
  versions?: (number | undefined)[]
  libraries?: ({ [libraryName: string]: string } | undefined)[]
  logOutput?: boolean
}

export type UpgradeOptions = {
  version?: number
  libraries?: { [libraryName: string]: string }
  logOutput?: boolean
}

export const deployProxy = async (
  contractName: string,
  args: any[],
  libraries: { [libraryName: string]: string } = {},
  version?: number,
  logOutput: boolean = false,
): Promise<BaseContract> => {
  const Contract = await ethers.getContractFactory(contractName, { libraries })
  const implementation = await Contract.deploy()
  await implementation.waitForDeployment()
  logOutput && console.log(`${contractName} impl.: ${await implementation.getAddress()}`)

  const proxyFactory = await ethers.getContractFactory("VeChainProxy")
  const proxy = await proxyFactory.deploy(
    await implementation.getAddress(),
    getInitializerData(Contract.interface, args, version),
  )
  await proxy.waitForDeployment()
  logOutput && console.log(`${contractName} proxy: ${await proxy.getAddress()}`)

  const newImplAddress = await getImplementationAddress(ethers.provider, await proxy.getAddress())
  const expectedAddress = await implementation.getAddress()
  if (newImplAddress.toLowerCase() !== expectedAddress.toLowerCase()) {
    throw new Error(`Implementation address mismatch: ${newImplAddress} !== ${expectedAddress}`)
  }

  return Contract.attach(await proxy.getAddress())
}

export const deployProxyOnly = async (
  contractName: string,
  libraries: { [libraryName: string]: string } = {},
  logOutput: boolean = false,
): Promise<string> => {
  const Contract = await ethers.getContractFactory(contractName, { libraries })
  const implementation = await Contract.deploy()
  await implementation.waitForDeployment()
  logOutput && console.log(`${contractName} impl.: ${await implementation.getAddress()}`)

  const proxyFactory = await ethers.getContractFactory("VeChainProxy")
  const proxy = await proxyFactory.deploy(await implementation.getAddress(), "0x")
  await proxy.waitForDeployment()
  logOutput && console.log(`${contractName} proxy: ${await proxy.getAddress()}`)

  const newImplAddress = await getImplementationAddress(ethers.provider, await proxy.getAddress())
  const expectedAddress = await implementation.getAddress()
  if (newImplAddress.toLowerCase() !== expectedAddress.toLowerCase()) {
    throw new Error(`Implementation address mismatch: ${newImplAddress} !== ${expectedAddress}`)
  }

  return await proxy.getAddress()
}

export const initializeProxy = async (
  proxyAddress: string,
  contractName: string,
  args: any[],
  libraries: { [libraryName: string]: string } = {},
  version?: number,
): Promise<BaseContract> => {
  const Contract = await ethers.getContractFactory(contractName, { libraries })
  const initializerData = getInitializerData(Contract.interface, args, version)

  const signer = (await ethers.getSigners())[0]
  const tx = await signer.sendTransaction({
    to: proxyAddress,
    data: initializerData,
    gasLimit: 10_000_000,
  })
  await tx.wait()

  return Contract.attach(proxyAddress)
}

export const upgradeProxy = async (
  previousVersionContractName: string,
  newVersionContractName: string,
  proxyAddress: string,
  args: any[] = [],
  options: UpgradeOptions,
): Promise<BaseContract> => {
  const Contract = await ethers.getContractFactory(newVersionContractName, {
    libraries: options.libraries,
  })
  const implementation = await Contract.deploy()
  await implementation.waitForDeployment()
  options.logOutput && console.log(`${newVersionContractName} impl.: ${await implementation.getAddress()}`)

  const currentContract = await ethers.getContractAt(previousVersionContractName, proxyAddress)

  const tx = await currentContract.upgradeToAndCall(
    await implementation.getAddress(),
    args.length > 0 ? getInitializerData(Contract.interface, args, options.version) : "0x",
  )
  await tx.wait()

  const newImplAddress = await getImplementationAddress(ethers.provider, proxyAddress)
  const expectedAddress = await implementation.getAddress()
  if (newImplAddress.toLowerCase() !== expectedAddress.toLowerCase()) {
    throw new Error(`Implementation address mismatch: ${newImplAddress} !== ${expectedAddress}`)
  }

  return Contract.attach(proxyAddress)
}

export const deployAndUpgrade = async (
  contractNames: string[],
  args: any[][],
  options: DeployUpgradeOptions,
): Promise<BaseContract> => {
  if (contractNames.length === 0) throw new Error("No contracts to deploy")
  if (contractNames.length !== args.length) throw new Error("Contract names and args must have the same length")

  let proxy = await deployProxy(
    contractNames[0],
    args[0],
    options.libraries?.[0],
    options.versions?.[0],
    options.logOutput,
  )

  for (let i = 1; i < contractNames.length; i++) {
    proxy = await upgradeProxy(
      contractNames[i - 1],
      contractNames[i],
      await proxy.getAddress(),
      args[i],
      { version: options.versions?.[i], libraries: options.libraries?.[i], logOutput: options.logOutput },
    )
  }

  return proxy
}

export function getInitializerData(contractInterface: Interface, args: any[], version?: number) {
  const initializer = version ? `initializeV${version}` : "initialize"
  const fragment = contractInterface.getFunction(initializer)
  if (!fragment) throw new Error(`Initializer "${initializer}" not found in contract ABI`)
  return contractInterface.encodeFunctionData(fragment, args)
}
```

### `scripts/deploy/deploy.ts`

Production deployment script. Uses the proxy helpers to deploy all contracts.

```typescript
import { ethers } from "hardhat"
import { deployProxy } from "../helpers/upgrades"
import { getConfig, AppConfig, AppEnv } from "@{{PROJECT_NAME}}/config"
import fs from "fs"
import path from "path"

async function main() {
  const [deployer] = await ethers.getSigners()
  console.log("Deploying with:", deployer.address)

  const helloWorld = await deployProxy("HelloWorld", [deployer.address, deployer.address], {}, undefined, true)
  const helloWorldAddress = await helloWorld.getAddress()
  console.log("HelloWorld deployed to:", helloWorldAddress)

  // Write addresses to config
  await writeConfig(helloWorldAddress)
}

async function writeConfig(helloWorldAddress: string) {
  const config = getConfig()
  const newConfig: AppConfig = {
    ...config,
    contracts: { helloWorld: helloWorldAddress },
  }

  const toWrite = `import { AppConfig } from "."
const config: AppConfig = ${JSON.stringify(newConfig, null, 2)}
export default config
`

  let fileToWrite: string
  switch (config.environment) {
    case AppEnv.LOCAL:
      fileToWrite = "local.ts"
      break
    case AppEnv.TESTNET:
      fileToWrite = "testnet.ts"
      break
    case AppEnv.MAINNET:
      fileToWrite = "mainnet.ts"
      break
    default:
      throw new Error(`Unsupported env: ${config.environment}`)
  }

  const configPath = path.resolve(__dirname, `../../../config/${fileToWrite}`)
  console.log(`Writing config to ${configPath}`)
  fs.writeFileSync(configPath, toWrite)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
```

### `scripts/upgrade/upgradesConfig.ts`

Registry of available contract upgrades. Add entries here when creating new versions.

```typescript
export interface UpgradeContract {
  name: string
  configAddressField: string
  versions: readonly string[]
  descriptions: Record<string, string>
}

export const upgradeConfig: Record<string, UpgradeContract> = {
  // Example: uncomment and adapt when you create HelloWorldV2
  // HelloWorld: {
  //   name: "hello-world",
  //   configAddressField: "helloWorld",
  //   versions: ["v2"],
  //   descriptions: {
  //     v2: "Description of what V2 changes",
  //   },
  // },
} as const
```

### `scripts/upgrade/select-and-upgrade.ts`

Interactive CLI for selecting and running upgrades.

```typescript
import inquirer from "inquirer"
import { upgradeConfig } from "./upgradesConfig"
import { getConfig } from "@{{PROJECT_NAME}}/config"
import { ethers, network } from "hardhat"
import { upgradeProxy } from "../helpers/upgrades"

async function main() {
  const env = process.env.NEXT_PUBLIC_APP_ENV
  if (!env) throw new Error("NEXT_PUBLIC_APP_ENV is not set")

  const config = getConfig()

  if (Object.keys(upgradeConfig).length === 0) {
    console.log("No upgrades configured yet. Add entries to upgradesConfig.ts first.")
    process.exit(0)
  }

  const { contract } = await inquirer.prompt<{ contract: keyof typeof upgradeConfig }>({
    type: "list",
    name: "contract",
    message: "Which contract do you want to upgrade?",
    choices: Object.keys(upgradeConfig),
  })

  const selected = upgradeConfig[contract]
  const { version } = await inquirer.prompt<{ version: string }>({
    type: "list",
    name: "version",
    message: `Which version do you want to upgrade ${contract} to?`,
    choices: selected.versions.map((v) => ({
      name: `${v} - ${selected.descriptions[v]}`,
      value: v,
    })),
  })

  const deployer = (await ethers.getSigners())[0]
  const address = (config.contracts as any)[selected.configAddressField]

  console.log(`\nContract: ${selected.name}`)
  console.log(`Address: ${address}`)
  console.log(`Version: ${version}`)
  console.log(`Upgrader: ${deployer.address}`)
  console.log(`Network: ${network.name}\n`)

  const { confirm } = await inquirer.prompt<{ confirm: boolean }>({
    type: "confirm",
    name: "confirm",
    message: "Proceed with upgrade?",
    default: false,
  })

  if (!confirm) {
    console.log("Upgrade aborted.")
    process.exit(0)
  }

  // The actual upgrade script should be in upgrades/{contract-name}/{contract-name}-{version}.ts
  // Import and run it dynamically, or call upgradeProxy directly:
  const versionNum = parseInt(version.replace("v", ""))
  const previousVersion = versionNum === 2 ? contract : `${contract}V${versionNum - 1}`
  const newVersion = contract // latest version uses the base name

  const upgraded = await upgradeProxy(
    String(previousVersion),
    String(newVersion),
    address,
    [], // reinitializer args - customize per upgrade
    { version: versionNum },
  )

  const newVer = await (upgraded as any).version()
  console.log(`Upgrade complete! New version: ${newVer}`)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
```

### `scripts/checkContractsDeployment.ts`

Checks if contracts are deployed on the current network. If not, deploys them via proxy helpers and writes addresses to the matching config file.

```typescript
import { ethers, network } from "hardhat"
import { getConfig, AppConfig, AppEnv } from "@{{PROJECT_NAME}}/config"
import { deployProxy } from "./helpers/upgrades"
import fs from "fs"
import path from "path"

const config = getConfig()
const env = config.environment

async function main() {
  console.log(`Checking contracts deployment on ${network.name} (${config.nodeUrl})...`)

  try {
    const code =
      config.contracts.helloWorld === "" || config.contracts.helloWorld === "0x0000000000000000000000000000000000000000"
        ? "0x"
        : await ethers.provider.getCode(config.contracts.helloWorld)

    if (code === "0x") {
      console.log(`HelloWorld contract not deployed at ${config.contracts.helloWorld}`)
      console.log(`Deploying contracts to ${network.name}...`)

      const [deployer] = await ethers.getSigners()
      const helloWorld = await deployProxy("HelloWorld", [deployer.address, deployer.address], {}, undefined, true)
      const address = await helloWorld.getAddress()

      await overrideConfigWithNewContracts(address)
    } else {
      console.log("Contracts already deployed")
    }
  } catch (e) {
    console.error(e)
  }

  process.exit(0)
}

async function overrideConfigWithNewContracts(helloWorldAddress: string) {
  const newConfig: AppConfig = {
    ...config,
    contracts: { helloWorld: helloWorldAddress },
  }

  const toWrite = `import { AppConfig } from "."
const config: AppConfig = ${JSON.stringify(newConfig, null, 2)}
export default config
`

  let fileToWrite: string
  switch (env) {
    case AppEnv.LOCAL:
      fileToWrite = "local.ts"
      break
    case AppEnv.TESTNET:
      fileToWrite = "testnet.ts"
      break
    case AppEnv.MAINNET:
      fileToWrite = "mainnet.ts"
      break
    default:
      throw new Error(`Unsupported NEXT_PUBLIC_APP_ENV: ${env}`)
  }

  const configPath = path.resolve(__dirname, `../../config/${fileToWrite}`)
  console.log(`Writing new config to ${configPath}`)
  fs.writeFileSync(configPath, toWrite)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
```

### `.gitignore`

```text
artifacts/
cache/
typechain-types/
node_modules/
coverage/
```

### `docker-compose.yaml`

Thor solo node for local development. Runs on port 8669 with on-demand block production and persistent data.

```yaml
services:
  thor-solo:
    image: ghcr.io/vechain/thor:latest
    hostname: thor-solo
    container_name: thor-solo
    user: root
    environment:
      - DOCKER=1
    entrypoint:
      [
        "/bin/sh",
        "-c",
        "apk update --no-cache && apk add --no-cache curl && thor solo --on-demand --persist --data-dir /data/thor --api-addr 0.0.0.0:8669 --api-cors '*' --verbosity 10",
      ]
    ports:
      - "8669:8669"
    healthcheck:
      test: curl --fail 0.0.0.0:8669/blocks/0 || exit 1
      interval: "2s"
      retries: 30
    volumes:
      - thor-data:/data/thor
    networks:
      - vechain-thor

networks:
  vechain-thor:
    driver: bridge
    name: vechain-thor
volumes:
  thor-data:
    driver: local
    name: thor-data
```

- `--on-demand` — produces blocks only when transactions arrive (faster tests)
- `--persist` — data survives container restarts (use `make solo-clean` to reset)
- Health check ensures `make solo-up` waits until the node is ready before returning

## `.github/workflows/deploy.yml`

Uses `/${{ github.event.repository.name }}` by default for GitHub Pages (`username.github.io/<repo-name>`).
Set to `""` if using a custom domain or if the repo is named `username.github.io`.
Note: `metadata.icons` and raw `<img src>` do NOT auto-prepend `basePath` — prefix them manually.

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
    paths:
      - "apps/frontend/**"
      - "packages/**"
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: yarn

      - run: yarn install --frozen-lockfile

      - run: yarn build
        env:
          NEXT_PUBLIC_BASE_PATH: "/${{ github.event.repository.name }}"
          NEXT_PUBLIC_NETWORK: "{{NETWORK_TYPE}}"
          NODE_OPTIONS: "--max-old-space-size=4096"

      - uses: actions/upload-pages-artifact@v3
        with:
          path: apps/frontend/out

  deploy:
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - id: deploy
        uses: actions/deploy-pages@v4
```
