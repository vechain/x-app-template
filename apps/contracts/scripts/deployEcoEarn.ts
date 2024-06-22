import { updateConfig, config } from '@repo/config-contract';
import { ethers } from 'hardhat';
async function deployMugshot() {
    const [owner] = await ethers.getSigners();

    const ecoEarn = await ethers.getContractFactory('EcoEarn');

    const ecoEarnInstance = await ecoEarn.deploy(
        owner,
        config.X2EARN_REWARDS_POOL,
        config.CYCLE_DURATION,
        config.MAX_SUBMISSIONS_PER_CYCLE,
        config.APP_ID
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
