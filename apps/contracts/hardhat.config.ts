import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';

import '@nomiclabs/hardhat-truffle5';
import '@vechain/sdk-hardhat-plugin';

require('dotenv').config();

const config: HardhatUserConfig = {
    solidity: '0.8.20',
};

module.exports = {
    solidity: {
        version: '0.8.20',
        evmVersion: 'paris',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    mocha: {
        timeout: 180000,
    },
    networks: {
        hardhat: {
            chainId: 1337,
        },
        vechain_solo: {
            url: 'http://localhost:8669',
            accounts: {
                mnemonic: 'denial kitchen pet squirrel other broom bar gas better priority spoil cross',
                count: 10,
                path: "m/44'/818'/0'/0",
            },
            restful: true,
            gas: 10000000,
            count: 10,
        },
        vechain_testnet: {
            url: process.env.TESTNET_URL ?? '',
            accounts: {
                mnemonic: process.env.MNEMONIC ?? '',
                count: 10,
                path: "m/44'/818'/0'/0",
            },
            restful: true,
            gas: 10000000,
            count: 10,
        },
        vechain_mainnet: {
            url: process.env.MAINNET_URL ?? '',
            accounts: {
                mnemonic: process.env.MNEMONIC ?? '',
                count: 1,
                path: "m/44'/818'/0'/0",
            },
            restful: true,
            gas: 10000000,
        },
    },
};

export default config;
