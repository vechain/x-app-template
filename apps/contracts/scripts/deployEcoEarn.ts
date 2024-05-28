import { updateConfig, config } from '@repo/config-contract';
import { ethers } from 'hardhat';
async function deployMugshot() {
    const [owner] = await ethers.getSigners();

    const ecoEarn = await ethers.getContractFactory('EcoEarn');

    const ecoEarnInstance = await ecoEarn.deploy(
        owner,
        config.TOKEN_ADDRESS,
        config.CYCLE_DURATION,
        config.MAX_SUBMISSIONS_PER_CYCLE,
    );

    const ecoEarnAddress = await ecoEarnInstance.getAddress();

    console.log(`EcoEarn deployed to: ${ecoEarnAddress}`);

    updateConfig({
        ...config,
        CONTRACT_ADDRESS: ecoEarnAddress,
    });
}

deployMugshot()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
