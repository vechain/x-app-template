import { ethers, network } from 'hardhat';
import { updateConfig, config } from '@repo/config-contract';
import { getABI } from '../utils/abi';

export async function deploy() {
    const deployer = (await ethers.getSigners())[0];
    console.log(`Deploying on ${network.name} with wallet ${deployer.address}...`);

    let REWARD_TOKEN_ADDRESS = config.TOKEN_ADDRESS;
    let X2EARN_REWARDS_POOL = config.X2EARN_REWARDS_POOL;
    let X2EARN_APPS = config.X2EARN_APPS;
    let APP_ID = config.APP_ID;

    // If we are running on the solo network, we need to deploy the mock contracts
    // and generate the appID
    if (network.name === 'vechain_solo') {
        console.log(`Deploying mock RewardToken...`);
        const RewardTokenContract = await ethers.getContractFactory('B3TR_Mock');
        const rewardToken = await RewardTokenContract.deploy();
        await rewardToken.waitForDeployment();
        REWARD_TOKEN_ADDRESS = await rewardToken.getAddress();
        console.log(`RewardToken deployed to ${REWARD_TOKEN_ADDRESS}`);

        console.log('Deploying X2EarnApps mock contract...');
        const X2EarnAppsContract = await ethers.getContractFactory('X2EarnAppsMock');
        const x2EarnApps = await X2EarnAppsContract.deploy();
        await x2EarnApps.waitForDeployment();
        X2EARN_APPS = await x2EarnApps.getAddress();
        console.log(`X2EarnApps deployed to ${await x2EarnApps.getAddress()}`);

        console.log('Deploying X2EarnRewardsPool mock contract...');
        const X2EarnRewardsPoolContract = await ethers.getContractFactory('X2EarnRewardsPoolMock');
        const x2EarnRewardsPool = await X2EarnRewardsPoolContract.deploy(deployer.address, REWARD_TOKEN_ADDRESS, await x2EarnApps.getAddress());
        await x2EarnRewardsPool.waitForDeployment();
        X2EARN_REWARDS_POOL = await x2EarnRewardsPool.getAddress();
        console.log(`X2EarnRewardsPool deployed to ${await x2EarnRewardsPool.getAddress()}`);

        console.log('Adding app in X2EarnApps...');
        await x2EarnApps.addApp(deployer.address, deployer.address, 'EcoEarn');
        const appID = await x2EarnApps.hashAppName('EcoEarn');
        APP_ID = appID;
        console.log(`AppID: ${appID}`);

        console.log(`Funding contract...`);
        await rewardToken.approve(await x2EarnRewardsPool.getAddress(), ethers.parseEther('10000'));
        await x2EarnRewardsPool.deposit(ethers.parseEther('2000'), appID);
        console.log('Funded');
    }

    console.log('Deploying EcoEarn contract...');
    const ecoEarn = await ethers.getContractFactory('EcoEarn');

    const ecoEarnInstance = await ecoEarn.deploy(
        deployer.address,
        X2EARN_REWARDS_POOL, // mock in solo, from config in testnet/mainnet
        config.CYCLE_DURATION,
        config.MAX_SUBMISSIONS_PER_CYCLE,
        APP_ID, // mock in solo, from config in testnet/mainnet
    );
    await ecoEarnInstance.waitForDeployment();

    const ecoEarnAddress = await ecoEarnInstance.getAddress();
    console.log(`EcoEarn deployed to: ${ecoEarnAddress}`);

    console.log('To start using the contract, we need to set the rewards amount and switch to the next cycle');

    const rewardsAmountResult = await (await ecoEarnInstance.setRewardsAmount(1000000000000000000000n)).wait();

    console.log('Rewards set reward amount to 1000');

    if (rewardsAmountResult == null || rewardsAmountResult.status !== 1) {
        throw new Error('Failed to set rewards amount');
    }

    const nextCycleResult = await (await ecoEarnInstance.setNextCycle(2n)).wait();

    if (nextCycleResult == null || nextCycleResult.status !== 1) {
        throw new Error('Failed to set next cycle');
    }

    console.log('Switched to next cycle');

    // In solo network, we need to add the EcoEarn contract as a distributor
    if (network.name === 'vechain_solo') {
        console.log('Add EcoEarn contracts as distributor...');
        const x2EarnApps = await ethers.getContractAt('X2EarnAppsMock', X2EARN_APPS);
        await x2EarnApps.addRewardDistributor(APP_ID, ecoEarnAddress);
        console.log('Added');
    }

    const ecoSolAbi = await getABI('EcoEarn');

    updateConfig(
        {
            ...config,
            CONTRACT_ADDRESS: ecoEarnAddress,
            TOKEN_ADDRESS: REWARD_TOKEN_ADDRESS,
        },
        ecoSolAbi,
    );

    console.log(`Done`);
}
