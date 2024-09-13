# Development Environment 

Get a local development environment up and running with as few steps as possible.

## Required Variables

- **OPENAI_API_KEY:** An OpenAI API key needs to be obtained manually from [OpenAI](https://platform.openai.com/api-keys):

## Start

```shell
yarn set version classic
yarn install
yarn contracts:solo-up
yarn contracts:deploy:solo

OPENAI_API_KEY="" \
 ADMIN_MNEMONIC="denial kitchen pet squirrel other broom bar gas better priority spoil cross" \
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
