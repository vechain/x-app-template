import { ADMIN_ADDRESS, ADMIN_PRIVATE_KEY, REWARD_AMOUNT } from '@/config';
import { HttpException } from '@/exceptions/HttpException';
import { Submission } from '@/interfaces/submission.interface';
import { thor } from '@/utils/thor';
import { Service } from 'typedi';
import { EcoEarnABI } from '@/utils/const';
import { ethers } from 'ethers';
import { config } from '@repo/config-contract';
import { TransactionHandler, clauseBuilder, coder } from '@vechain/sdk-core';
@Service()
export class ContractsService {
  public async registerSubmission(submission: Submission): Promise<void> {
    const clause = clauseBuilder.functionInteraction(
      config.CONTRACT_ADDRESS,
      coder.createInterface(EcoEarnABI).getFunction('registerValidSubmission'),
      [submission.address, `0x${ethers.parseEther(REWARD_AMOUNT).toString(16)}`],
    );

    const gasResult = await thor.gas.estimateGas([clause], ADMIN_ADDRESS);

    if (gasResult.reverted === true) throw new HttpException(500, `EcoEarn: Internal server error: ${gasResult.revertReasons}`);

    const txBody = await thor.transactions.buildTransactionBody([clause], gasResult.totalGas);

    const signedTx = TransactionHandler.sign(txBody, Buffer.from(ADMIN_PRIVATE_KEY));

    await thor.transactions.sendTransaction(signedTx);
  }

  public async validateSubmission(submission: Submission): Promise<void> {
    const isMaxSubmissionsReached = await thor.contracts.executeCall(
      config.CONTRACT_ADDRESS,
      coder.createInterface(EcoEarnABI).getFunction('isUserMaxSubmissionsReached'),
      [submission.address],
    );

    if (Boolean(isMaxSubmissionsReached[0]) === true) throw new HttpException(409, `EcoEarn: Max submissions reached for this cycle`);
  }
}
