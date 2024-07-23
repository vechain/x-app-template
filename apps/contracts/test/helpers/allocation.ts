import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { EcoEarn, B3TR_Mock, X2EarnRewardsPoolMock } from '../../typechain-types';
import { ethers } from 'ethers';

export const receiveAllocations = async (
    mugshot: EcoEarn,
    token: B3TR_Mock,
    owner: HardhatEthersSigner,
    admin: HardhatEthersSigner,
    amount: string,
    x2EarnRewardsPool: X2EarnRewardsPoolMock,
    appId: string,
) => {
    await token.connect(owner).mint(admin, ethers.parseEther(amount));

    await token.connect(admin).approve(await x2EarnRewardsPool.getAddress(), ethers.parseEther(Number.MAX_SAFE_INTEGER.toString()));
    await x2EarnRewardsPool.connect(admin).deposit(ethers.parseEther(amount), appId);

    await mugshot.connect(admin).setRewardsAmount(ethers.parseEther(amount));
};
