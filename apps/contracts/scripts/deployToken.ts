import { updateConfig, config } from '@repo/config-contract';
import { ethers } from 'hardhat';

async function deployToken() {
    const [owner] = await ethers.getSigners();

    const token = await ethers.getContractFactory('Token');
    const tokenInstance = await token.deploy(owner);

    const tokenAddress = await tokenInstance.getAddress();

    console.log(`Token deployed to: ${tokenAddress}`);

    updateConfig({
        ...config,
        TOKEN_ADDRESS: tokenAddress,
    });
}

deployToken()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
