import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { EcoEarn, B3TR_Mock } from '../../typechain-types';
import { ethers } from 'ethers';

export const receiveAllocations = async (
    mugshot: EcoEarn,
    token: B3TR_Mock,
    owner: HardhatEthersSigner,
    admin: HardhatEthersSigner,
    amount: string,
) => {
    await token.connect(owner).mint(admin, ethers.parseEther(amount));

    await token.connect(admin).approve(await mugshot.getAddress(), ethers.parseEther(Number.MAX_SAFE_INTEGER.toString()));

    await mugshot.connect(admin).claimAllocation(ethers.parseEther(amount));
};
