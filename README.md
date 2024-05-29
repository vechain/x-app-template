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

Unlock the potential of decentralized application development on Vechain with our X-App template for VeBetterDAO. Designed for the Vechain Thor blockchain, this template integrates cutting-edge technologies such as React, TypeScript, Hardhat, and Express, ensuring a seamless and efficient DApp development experience. 🌟

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
- **OpenAI GPT-Vision-Preview:** Integrate image analysis capabilities. [Explore here](https://platform.openai.com/docs/guides/vision)

### Contracts (apps/contracts) 📜

Smart contracts in Solidity, managed with Hardhat for deployment on the Vechain Thor network.

### Packages 📦

Shared configurations and utility functions to unify and simplify your development process.

## Environment Variables ⚙️

Configure your environment variables for seamless integration:

### Frontend

Place your `.env` files in `apps/frontend`:
- **VITE_RECAPTCHA_V3_SITE_KEY:** [Request your RecaptchaV3 site keys](https://developers.google.com/recaptcha/docs/v3)

### Backend

Store your environment-specific `.env` files in `apps/backend`. `.env.development.local` & `.env.production.local` allow for custom environment variables based on the environment:
- **OPENAI_API_KEY:** [Get your GPT-4 OpenAI key](https://platform.openai.com/api-keys) (Enable GPT-4 [here](https://help.openai.com/en/articles/7102672-how-can-i-access-gpt-4-gpt-4-turbo-and-gpt-4o))
- **RECAPTCHA_SECRET_KEY:** [Request your RecaptchaV3 site keys](https://developers.google.com/recaptcha/docs/v3)

### Contracts

Manage deployment parameters and network configurations in `hardhat.config.js` under `apps/contracts`:
- **MNEMONIC:** Mnemonic of the deploying wallet

## Getting Started 🏁

Clone the repository and install dependencies with ease:
```bash
yarn install # Run this at the root level of the project
```

## Deploying Contracts 🚀

Deploy your contracts effortlessly on either the Testnet or Solo networks:

### Deploying on Solo Network

```bash
yarn contracts:deploy:solo
```

### Deploying on Testnet

```bash
yarn contracts:deploy:testnet
```

## Running on Solo Network 🔧

Run the Frontend and Backend, connected to the Solo network and pointing to your deployed contracts. Ensure all environment variables are properly configured:
```bash
yarn dev 
```

### Setting up rewards
Run vechain devpal 
```bash
npx @vechain/devpal http://localhost:8669
```

Open the `Inspector` tab and perform the following transactions:
- **Add Contracts:** Add the EcoEarn contract and the Token contract deployed previously. Addresses can be found in the `config-contracts` package. ABIs can be found in the artifacts folder of the `contracts` app.
![image](https://github.com/vechain/x-app-template/assets/64158778/e288ada4-5973-4428-9e72-a362388b1826)
- **Approve token:** Approve the EcoEarn contract to spend your tokens
![image](https://github.com/vechain/x-app-template/assets/64158778/70787d8d-ae60-40ea-b277-87359aaca4ee)
- **Claim rewards:** Claim rewards for the EcoEarn contract
![image](https://github.com/vechain/x-app-template/assets/64158778/834437e5-8de1-4802-9ed7-dca6fe4df332)
- **Trigger cycle:** Trigger the cycle for the EcoEarn contract
![image](https://github.com/vechain/x-app-template/assets/64158778/00236dcd-5b64-4493-9acd-55c6a7f0981f)

## Disclaimer ⚠️

This template serves as a foundational starting point and should be thoroughly reviewed and customized to suit your project’s specific requirements. Pay special attention to configurations, security settings, and environment variables to ensure a secure and efficient deployment.

---

Embrace the power of VeBetterDAO's X-Apps template and transform your DApp development experience. Happy coding! 😄
