# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

## Sample `hardhat.config.js` with fee delegation

Fee delegation can be configured by providing optional ```delegate``` config which has required ``url`` and optional ``signer`` field. Url needs to point to delegation a valid
delegation service, for example ```https://sponsor-testnet.vechain.energy/by/${projectId}```.
```js
module.exports = {
    solidity: {
        version: "0.8.17",
    },
    networks: {
        vechain: {
            url: "https://testnet.veblocks.net/",
            delegate: {
                url: "${feeDelegationServiceUrl}",
                signer: "${optionalSigner}"
            }
        },
    }
};
```

## Clauses support

Vechain Thor network supports sending multiple clauses as part of one transaction. Clauses are then executed atomically on
a chain. Hardhat plugin supports Vechain tx construction with multiple clauses. Example code:

```js
const clauseBuilder = new ClausesBuilder(baseContract);
const tx = await clauseBuilder.withClause({
    args: [1],
    abi: JSON.stringify([{ type: 'function', name: 'method1'}] ),
    method: 'method1'
}).withClause({
    args: [2],
    abi: JSON.stringify([{ type: 'function', name: 'method2'}] ),
    method: 'method2'
}).send()
```

## Multi network support sample `hardhat.config.js`

Multiple network can also be configured to simplify testing and deployments. Networks which are targeting ``VechainThor``
nodes should have ```vechain``` as part of the network name (vechain, vechain_testnet, vechainNode are all valid). Network
names without this requirement won't be preprocessed by the plugin and it is not expected to function properly with Thor
network. Sample configuration:

```js
const {
  VECHAIN_URL_SOLO
} = require("@vechain/hardhat-vechain");
require("@vechain/hardhat-web3");

module.exports = {
    solidity: {
        version: "0.8.17",
    },
    networks: {
        vechain_solo: {
            url: VECHAIN_URL_SOLO,
        },
        vechain_mainnet: {
            url: "https://mainnet.veblocks.net",
        },
    }
};
```
Multi network configuration can be tested with:

```shell
npx hardhat test --network vechain_solo  
```

Thor solo node can be started via docker-compose
```shell
docker-compose up -d  
```

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test --network vechain
REPORT_GAS=true npx hardhat test --network vechain
npx hardhat node
npx hardhat run scripts/deploy.ts --network vechain
```
