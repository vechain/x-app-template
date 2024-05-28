import { ethers } from 'hardhat';

export const CYCLE_DURATION = 10; // 10 blocks

export const TOKEN_REWARDS_PER_SUBMISSION = 5;
export const MAX_SUBMISSIONS_PER_CYCLE = 2;
export const REWARDS_PERCENTAGE_FOR_USERS = 80;

export const getAndDeployContracts = async () => {
    // Contracts are deployed using the first signer/account by default
    const [owner, admin, account3, account4, ...otherAccounts] = await ethers.getSigners();

    const tokenContract = await ethers.getContractFactory('Token');
    const token = await tokenContract.deploy(owner);

    const ecoEarnContract = await ethers.getContractFactory('EcoEarn');
    const ecoearn = await ecoEarnContract.deploy(admin, await token.getAddress(), CYCLE_DURATION, MAX_SUBMISSIONS_PER_CYCLE);

    return { token, ecoearn, owner, admin, account3, account4, otherAccounts };
};
