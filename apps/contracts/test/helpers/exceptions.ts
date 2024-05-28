import { assert } from 'chai';
import { ContractTransactionResponse } from 'ethers';
import { network } from 'hardhat';

async function tryCatch(promise: Promise<ContractTransactionResponse>, reason: any) {
    try {
        const tx: ContractTransactionResponse = await promise;
        await tx.wait();
        throw null;
    } catch (error: any) {
        assert(error, 'Expected an error but did not get one');
        assert(error.message.includes(reason), `Expected an ${reason} error`);
    }
}
const revertReason = network.name === 'hardhat' ? 'VM Exception while processing transaction' : 'execution reverted';
export const catchRevert = async function (promise: Promise<ContractTransactionResponse>) {
    await tryCatch(promise, revertReason);
};
export const catchOutOfGas = async function (promise: Promise<ContractTransactionResponse>) {
    await tryCatch(promise, 'out of gas');
};
