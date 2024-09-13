## Watch the Tutorial

[![Watch the video](https://github.com/user-attachments/assets/462958d6-1be5-4598-b035-95f4ef818f16)](https://www.youtube.com/watch?v=fmm2IDMuYjE)

# X-App Template for VeBetterDAO 🚀

                                     #######
                                ################
                              ####################
                            ###########   #########
                           #########      #########
         #######          #########       #########
         #########       #########      ##########
          ##########     ########     ####################
           ##########   #########  #########################
             ################### ############################
              #################  ##########          ########
                ##############      ###              ########
                 ############                       #########
                   ##########                     ##########
                    ########                    ###########
                      ###                    ############
                                         ##############
                                   #################
                                  ##############
                                  #########

> [!TIP]
> Impatient? Check out the [QuickStart](./QuickStart.md) to instantly run the app template.

Unlock the potential of decentralized application development on Vechain with our X-App template for VeBetterDAO. Designed for the Vechain Thor blockchain, this template integrates cutting-edge technologies such as React, TypeScript, Hardhat, and Express, ensuring a seamless and efficient DApp development experience. 🌟

Read more about the implementation and key features of this template in our [Developer Docs](https://docs.vebetterdao.org/developer-guides/integration-examples/pattern-2-use-smart-contracts-and-backend).

This template uses the VeBetterDAO ecosystem to distribute rewards to users. To learn more about VeBetterDAO, visit our [documentation](https://docs.vebetterdao.org/developer-guides/integration-examples).

When using the solo node you can import the following mnemonic into your wallet and have access to 10 pre-funded accounts:

```
denial kitchen pet squirrel other broom bar gas better priority spoil cross
```

## Requirements

Ensure your development environment is set up with the following:

- **Node.js (v18 or later):** [Download here](https://nodejs.org/en/download/package-manager) 📥
- **Yarn:** [Install here](https://classic.yarnpkg.com/lang/en/docs/install/#mac-stable) 🧶
- **Docker (for containerization):** [Get Docker](https://docs.docker.com/get-docker/) 🐳
- **Hardhat (for smart contracts):** [Getting Started with Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started) ⛑️

## Project Structure

### Frontend (apps/frontend) 🌐

A blazing-fast React application powered by Vite:

- **Vechain dapp-kit:** Streamline wallet connections and interactions. [Learn more](https://docs.vechain.org/developer-resources/sdks-and-providers/dapp-kit)

### Backend (apps/backend) 🔙

An Express server crafted with TypeScript for robust API development:

- **Vechain SDK:** Seamlessly fetch and perform transactions with the VechainThor blockchain. [Learn more](https://docs.vechain.org/developer-resources/sdks-and-providers/sdk)
- **OpenAI GPT-4o:** Integrate image analysis capabilities. [Explore here](https://platform.openai.com/docs/guides/vision)

### Contracts (apps/contracts) 📜

Smart contracts in Solidity, managed with Hardhat for deployment on the Vechain Thor network.

### Packages 📦

Shared configurations and utility functions to unify and simplify your development process.

## Environment Variables ⚙️

Configure your environment variables for seamless integration:

### Backend

Store your environment-specific `.env` files in `apps/backend`. `.env.development.local` & `.env.production.local` allow for custom environment variables based on the environment:

- **OPENAI_API_KEY:** [Get your GPT-4 OpenAI key](https://platform.openai.com/api-keys) (Enable GPT-4 [here](https://help.openai.com/en/articles/7102672-how-can-i-access-gpt-4-gpt-4-turbo-and-gpt-4o))

### Contracts

Manage deployment parameters and network configurations in `hardhat.config.js` under `apps/contracts`:

- **MNEMONIC:** Mnemonic of the deploying wallet

## Getting Started 🏁

Clone the repository and install dependencies with ease:

```bash
yarn install # Run this at the root level of the project
```

### Run locally

#### Deploy contracts

To start deploying contract locally you must run a local instance of the Vechain Thor blockchain. You can do this by running the following command:

```bash
yarn contracts:solo-up
```

This command will also start a local instance of the tools Insight (http://localhost:8080/) and Inspector (http://localhost:8081/).

At this point you can deploy the contracts to the local network by running:

```bash
yarn contracts:deploy:solo
```

Once the deployment is completed successfully you can go ahead and start the frontend and backend:

> ⚠️ **Warning:**
> Remember to set the OPENAI_API_KEY env variable in the backend .env.development.local file. Refer to the [Environment Variables](#environment-variables) section for more information.

```bash
yarn dev
```

At this point you can access the frontend at [http://localhost:8082/](http://localhost:8082/).

Start uploading a receipt!

## Deploying on Testnet 🚀

To distribute rewards this contract needs of a valid APP_ID provided by VeBetterDAO when joining the ecosystem.
In testnet you can generate the APP_ID by using the [VeBetterDAO sandbox](https://dev.testnet.governance.vebetterdao.org/).
This contract can be initially deployed without this information and DEFAULT_ADMIN_ROLE can update it later through {EcoEarn-setAppId}.

This contract must be set as a `rewardDistributor` inside the X2EarnApps contract to be able to send rewards to users and withdraw.

For deploying on Testnet you should check that you have the correct addresses in the `config-contracts` package (generated on the [VeBetterDAO sandbox](https://dev.testnet.governance.vebetterdao.org/)).

When deploying on the SOLO network the script will deploy for you the mocked VeBetterDAO contracts and generate an APP_ID.

Once everything is set up you can deploy the contracts to the testnet by running:

```bash
yarn contracts:deploy:testnet
```

## Triggering Cycles and Setting the Rewards

The deployment scripts will configure the 1st cycle for you with a reward of 1000 tokens.

To start a new cycle and set the rewards you can follow the steps below:

### Testnet

Read the [VeBetterDAO documentation](https://docs.vebetterdao.org/developer-guides/test-environmnet) to learn how to set up rewards for your users and use the Testnet environment.

Test environment: [https://dev.testnet.governance.vebetterdao.org/](https://dev.testnet.governance.vebetterdao.org/)

[TEST ENVIRONMENT DEMO](https://streamable.com/e/175r1s?quality=highest)

Thanks to the test environment you will be able to mint and deposit B3TR tokens int the rewards pool that you will use to distribute rewards to users.

Now you just need to trigger cycles and set amount of rewards per cycle on your EcoEarn contract.

1. Go to our online [inspector app](https://solid-funicular-1wmop55.pages.github.io/#/contracts) that you can use to interact with your contracts. Be sure to select the correct network (Testnet).

2. Add the `EcoEarn` contract to the inspector app. Get the address from `config-contracts` package and the ABI from the `apps/contracts/artifacts/contracts/EcoEarn.sol/EcoEarn.json` file.
   ![image](https://i.ibb.co/TK8519c/SCR-20240723-kjid.png)

3. Set how many rewards you want to distribute per cycle:
   ![image](https://i.ibb.co/qpJnL5x/SCR-20240723-kkti.png)

4. Trigger a cycle:
   ![image](https://i.ibb.co/47V2Zjb/SCR-20240723-kkxx.png)

### Solo Network

Since the Solo network is a local network with mocked VeBetterDAO contracts you can use the following steps to set up available rewards to distribute to users:

0. Ensure you are using a wallet with imported pre-funded accounts mnemonic into your wallet. Mnemonic:

```
denial kitchen pet squirrel other broom bar gas better priority spoil cross
```

1. Copy the `APP_ID` generated by the `contracts:deploy:solo` script and logged in the console.
2. Open the [inspector app](http://localhost:8081/#/contracts), running on localhost, that you can use to interact with your contracts.

3. Open the `Inspector` tab and perform the following actions:
4. Add the B3TR_Mock contract (get the address from the console logs and ABI from the `apps/contracts/artifacts/contracts/mock/B3TR_Mock.sol/B3TR_Mock.json` file)
   ![image](https://i.ibb.co/6Zrj7Nx/SCR-20240723-jorq.png)
5. Add the X2EarnRewardsPool contract (get the address from the console logs and ABI from the `apps/contracts/artifacts/contracts/mock/X2EarnRewardsPoolMock.sol/X2EarnRewardsPoolMock.json` file)
   ![image](https://i.ibb.co/yYjLw9v/SCR-20240723-jozk.png)
6. You should now have the following setup:
   ![image](https://i.ibb.co/w4XWyh9/SCR-20240723-jpbc.png)
7. To recharge the rewards pool you will need to mint some mocked B3TR tokens, then deposit them into the rewards pool. Perform the following actions:
   - Mint some tokens by calling the `mint` function on the B3TR_Mock contract
     ![image](https://i.ibb.co/XCQ7LNR/SCR-20240723-kgll.png)
   - Approve the X2EarnRewards contract to spend the tokens by calling the `approve` function on the B3TR_Mock contract
     ![image](https://i.ibb.co/X7Txx7Y/SCR-20240723-keuu.png)
   - Deposit the tokens into the rewards pool by calling the `deposit` function on the X2EarnRewardsPool contract
     ![image](https://i.ibb.co/X7Txx7Y/SCR-20240723-keuu.png)
8. Now you just need to set how many rewards you want to distribute per cycle and trigger the start of the cycle

- Add the `EcoEarn` contract to the inspector app. Get the address from `config-contracts` package and the ABI from the `apps/contracts/artifacts/contracts/EcoEarn.sol/EcoEarn.json` file.
  ![image](https://i.ibb.co/TK8519c/SCR-20240723-kjid.png)

- Set how many rewards you want to distribute per cycle:
  ![image](https://i.ibb.co/qpJnL5x/SCR-20240723-kkti.png)

- Trigger a cycle:
  ![image](https://i.ibb.co/47V2Zjb/SCR-20240723-kkxx.png)

NB: Values are in wei, use this tool to convert to VET: [https://eth-converter.com/](https://eth-converter.com/)

## Disclaimer ⚠️

This template serves as a foundational starting point and should be thoroughly reviewed and customized to suit your project’s specific requirements. Pay special attention to configurations, security settings, and environment variables to ensure a secure and efficient deployment.

---

Embrace the power of VeBetterDAO's X-Apps template and transform your DApp development experience. Happy coding! 😄
