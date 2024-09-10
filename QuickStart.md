# Development Environment 

Get a local development environment up and running with as few steps as possible.

## Required Variables

- **OPENAI_API_KEY:** [Get your GPT-4 OpenAI key](https://platform.openai.com/api-keys)

## Start

```shell
yarn set version classic
yarn install
yarn contracts:solo-up
yarn contracts:deploy:solo

PORT=3000 \
 ORIGIN="*" \
 OPENAI_API_KEY="sk-proj-.." \
 ADMIN_MNEMONIC="denial kitchen pet squirrel other broom bar gas better priority spoil cross" \
 NETWORK_URL=http://localhost:8669 \
 REWARD_AMOUNT=1 \
 yarn dev
```

## Result

Link | Service 
--- | ---
http://localhost:8082 | Frontend
http://localhost:3000 | Backend
http://localhost:8081 | Inspector
http://localhost:8669 | Solo Thor

Deployed contracts documented in: [packages/config-contract/config.ts](packages/config-contract/config.ts)

## Shutdown

```shell
yarn contracts:solo-down
```
