import { ethers } from 'hardhat';

export const CYCLE_DURATION = 10; // 10 blocks

export const TOKEN_REWARDS_PER_SUBMISSION = 5;
export const MAX_SUBMISSIONS_PER_CYCLE = 2;
export const REWARDS_PERCENTAGE_FOR_USERS = 80;

export const getAndDeployContracts = async () => {
    // Contracts are deployed using the first signer/account by default
    const [owner, admin, account3, account4, ...otherAccounts] = await ethers.getSigners();

    const RewardTokenContract = await ethers.getContractFactory('B3TR_Mock');
    const rewardToken = await RewardTokenContract.deploy();
    await rewardToken.waitForDeployment();

    const X2EarnAppsContract = await ethers.getContractFactory('X2EarnAppsMock');
    const x2EarnApps = await X2EarnAppsContract.deploy();
    await x2EarnApps.waitForDeployment();

    const X2EarnRewardsPoolContract = await ethers.getContractFactory('X2EarnRewardsPoolMock');
    const x2EarnRewardsPool = await X2EarnRewardsPoolContract.deploy(admin.address, await rewardToken.getAddress(), await x2EarnApps.getAddress());
    await x2EarnRewardsPool.waitForDeployment();

    await x2EarnApps.addApp(admin.address, admin.address, 'EcoEarn');
    const APP_ID = await x2EarnApps.hashAppName('EcoEarn');

    const ecoEarn = await ethers.getContractFactory('EcoEarn');
    const ecoEarnInstance = await ecoEarn.deploy(
        admin.address,
        await x2EarnRewardsPool.getAddress(),
        CYCLE_DURATION,
        MAX_SUBMISSIONS_PER_CYCLE,
        APP_ID,
    );
    await ecoEarnInstance.waitForDeployment();
    const ecoEarnAddress = await ecoEarnInstance.getAddress();

    await x2EarnApps.connect(admin).addRewardDistributor(APP_ID, ecoEarnAddress);

    return {
        token: rewardToken,
        ecoearn: ecoEarnInstance,
        x2EarnApps,
        x2EarnRewardsPool,
        appId: APP_ID,
        owner,
        admin,
        account3,
        account4,
        otherAccounts,
    };
};
