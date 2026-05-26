# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

X-App template for **VeBetterDAO** on VeChainThor. Reference flow: user uploads a purchase-receipt image in the React frontend → Express backend asks OpenAI (GPT-4o vision) to score the receipt → if `validityFactor > 0.5`, the backend's admin-signed wallet calls `EcoEarn.registerValidSubmission`, which distributes B3TR via VeBetterDAO's `X2EarnRewardsPool`.

The repo is a Turborepo + Yarn 1 (classic) workspaces monorepo: `apps/{frontend,backend,contracts}` + shared `packages/{config-contract,config-typescript,utils}`.

## Commands

All scripts run from the repo root and are dispatched by Turbo unless noted.

```bash
yarn install                       # install all workspaces (must be yarn classic)

# Local dev loop (in this order)
yarn contracts:solo-up             # `docker compose up -d` in apps/contracts; starts Thor solo, Insight, Inspector
yarn contracts:deploy:solo         # deploys mocks + EcoEarn to solo; REWRITES packages/config-contract/config.ts
OPENAI_API_KEY=... ADMIN_MNEMONIC="denial kitchen pet squirrel other broom bar gas better priority spoil cross" yarn dev
yarn contracts:solo-down           # stop docker stack

# Other
yarn build                         # turbo build (frontend tsc+vite, backend swc, packages tsc)
yarn lint / yarn lint:fix          # turbo lint (eslint, max-warnings 0 on frontend)
yarn test                          # turbo test (depends on ^lint)
yarn contracts:compile             # hardhat compile
yarn contracts:test                # hardhat test (network hardhat)
yarn contracts:deploy:testnet      # needs TESTNET_URL + MNEMONIC env vars
yarn format                        # prettier across the repo
```

Ports: frontend `8082`, backend `3000`, Thor solo `8669`, Inspector `8081`, Insight `8080`.

### Running a single contract test

```bash
cd apps/contracts && npx hardhat test test/EcoEarn.test.ts --network hardhat
# or against a running solo node:
cd apps/contracts && npx hardhat test test/EcoEarn.test.ts --network vechain_solo
```

There is no Jest/Vitest test runner wired into the backend; `yarn test` in backend is currently a no-op via Turbo. Frontend has no test target either. Tests live only in `apps/contracts/test/`.

## Architecture

### Reward flow (read this before touching anything)

1. **Frontend** (`apps/frontend/src/components/Dropzone.tsx` → `networking/submitReceipt.ts`) posts a base64 image + connected wallet address to `POST /submitReceipt`.
2. **Backend** `SubmissionController.submitReceipt` (`apps/backend/src/controllers/submission.controller.ts`):
   - Calls `ContractsService.validateSubmission` → reads `EcoEarn.isUserMaxSubmissionsReached` (rejects if user hit the per-cycle cap).
   - Calls `OpenaiService.validateImage` with a fixed prompt that returns `{ validityFactor, descriptionOfAnalysis }`.
   - If `validityFactor > 0.5` → `ContractsService.registerSubmission` → admin wallet signs `registerValidSubmission(address, REWARD_AMOUNT)` on the EcoEarn contract.
3. **`EcoEarn.registerValidSubmission`** (`apps/contracts/contracts/EcoEarn.sol`) checks cycle/cap/funds and calls `X2EarnRewardsPool.distributeReward(appId, amount, participant, '')` — that contract transfers B3TR.

The backend wallet is the **`DEFAULT_ADMIN_ROLE`** holder and the **`rewardDistributor`** registered in `X2EarnApps`. Lose the mnemonic and the deployed contract is no longer driveable.

### The `packages/config-contract` is the source of truth

`packages/config-contract/config.ts` is **generated** by `apps/contracts/scripts/deploy.ts` via `updateConfig()`, which `fs.writeFileSync`s the file with the new `CONTRACT_ADDRESS`, `TOKEN_ADDRESS`, and `ECO_SOL_ABI`. Both the backend (`apps/backend/src/utils/thor.ts`) and any frontend that imports it consume this generated file. Implications:

- After every `deploy:solo` / `deploy:testnet`, this file is overwritten — don't hand-edit it; edits will be lost on the next deploy.
- The pre-committed values in `config.ts` are **testnet** addresses for `X2EARN_REWARDS_POOL`, `X2EARN_APPS`, `APP_ID`. Solo deploys overwrite them with mock addresses; redeploying to solo and then to testnet requires re-supplying testnet addresses.
- A separate stale `EcoEarnABI` exists at `apps/backend/src/utils/const/abi.ts` — it is **not** what `thor.ts` actually loads (`ECO_SOL_ABI` from `@repo/config-contract` is). Treat the backend `const/abi.ts` as dead weight unless wiring it back in.

### Solo vs testnet/mainnet

`apps/contracts/scripts/deploy.ts` branches on `network.name === 'vechain_solo'`:
- **Solo:** deploys `B3TR_Mock`, `X2EarnAppsMock`, `X2EarnRewardsPoolMock`, hashes the app name to derive `APP_ID`, deposits 2000 mock B3TR into the rewards pool, adds the EcoEarn contract as a reward distributor.
- **Testnet/mainnet:** uses the addresses already in `config.ts` and the externally-issued `APP_ID` (generated via the [VeBetterDAO sandbox](https://dev.testnet.governance.vebetterdao.org/)). The deployed contract has no funds until you mint/deposit B3TR through the sandbox and call `setRewardsAmount` + `triggerCycle` via the inspector.

Hardhat networks (in `apps/contracts/hardhat.config.ts`) all derive accounts from a mnemonic at path `m/44'/818'/0'/0` (VeChain). Solo uses the well-known prefunded mnemonic; testnet/mainnet read `MNEMONIC` from env.

### Backend specifics

- Stack: Express + `typedi` (DI via `@Service` + `Container.get`), envalid for env validation, SWC for build, nodemon + cross-env for dev.
- `apps/backend/src/server.ts` instantiates `App` with a single `SubmissionRoute`; OpenAI is initialized at module load (`openAIHelper = initializeOpenAI()`).
- `apps/backend/src/utils/thor.ts` builds the VeChain `ThorClient` against `NETWORK_URL` (default `http://localhost:8669`) and derives the admin signer from `ADMIN_MNEMONIC` via `@vechain/sdk-core`'s `mnemonic.derivePrivateKey`.
- `ValidateEnv` (`apps/backend/src/utils/validateEnv.ts`) enforces `OPENAI_API_KEY` matches `/^sk-proj-.{100,}$/` — older `sk-...` keys will be rejected.
- Env files live in `apps/backend/.env.{development,production}.local` (selected by `NODE_ENV`).

### Frontend specifics

- React 18 + Vite + Chakra UI v2 + `@vechain/dapp-kit-react` for wallet connect.
- `App.tsx` hard-codes `nodeUrl="https://testnet.vechain.org/"` and `genesis="test"` — **the frontend talks to testnet by default even when contracts are deployed to solo.** Change this when running fully local.
- Backend URL is hardcoded in `apps/frontend/src/config.ts` to `http://localhost:3000` — update for any non-local deploy.
- State: Zustand (`hooks/useSubmission.ts`) plus a custom `useDisclosure`.

### Contracts

- Solidity `0.8.20`, `evmVersion: paris`, optimizer 200 runs.
- `EcoEarn.sol` is `AccessControl`-based with a single `DEFAULT_ADMIN_ROLE`. Cycles are advanced manually via `triggerCycle`; `getCurrentCycle() == nextCycle - 1` (so the deploy script bumps `nextCycle` to 2 to make cycle 1 "current").
- Tests in `apps/contracts/test/EcoEarn.test.ts` use the OpenZeppelin v5 patterns and the local mocks under `contracts/mock/`.

## Gotchas

- **Yarn classic only.** `package.json` pins `packageManager: yarn@1.22.21`. The QuickStart explicitly runs `yarn set version classic`.
- **Top-level `resolutions` block** forces specific versions of `elliptic`, `cipher-base`, `sha.js`, `pbkdf2`, `adm-zip`, `base-x`, `secp256k1` (security pins). Re-add equivalent pins if introducing new resolutions.
- The CI workflow (`.github/workflows/build-and-test.yml`) runs `yarn build && yarn lint && yarn test` on PRs to `main`. The frontend lint is `--max-warnings 0` — warnings will fail CI.
- When deploying to testnet, `EcoEarn` is **not** automatically registered as a `rewardDistributor`; you must do this through the VeBetterDAO sandbox or it will fail at `distributeReward` time.
- `getCurrentCycle()` underflows if you call it before `nextCycle` has been bumped past 1 — the deploy script's `setNextCycle(2n)` is load-bearing.
