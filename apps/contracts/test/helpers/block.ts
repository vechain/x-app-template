import { mine } from '@nomicfoundation/hardhat-network-helpers';
import { ethers, network } from 'hardhat';
import { EcoEarn } from '../../typechain-types';

export const waitForNextBlock = async () => {
    if (network.name === 'hardhat') {
        await mine(1);
        return;
    }

    // since we do not support ethers' evm_mine yet, we need to wait for a block with a timeout function
    const startingBlock = await ethers.provider.getBlockNumber();
    let currentBlock;
    do {
        await new Promise(resolve => setTimeout(resolve, 1000));
        currentBlock = await ethers.provider.getBlockNumber();
    } while (startingBlock === currentBlock);
};

export const moveBlocks = async (blocks: number) => {
    for (let i = 0; i < blocks; i++) {
        await waitForNextBlock();
    }
};

export const waitForNextCycle = async (mugshot: EcoEarn) => {
    const nextCycleBlock = await mugshot.getNextCycleBlock();

    await moveBlocks(Number(nextCycleBlock) - (await ethers.provider.getBlockNumber()));
};
