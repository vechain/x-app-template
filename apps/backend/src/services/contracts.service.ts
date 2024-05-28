import { ADMIN_ADDRESS, ADMIN_PRIVATE_KEY, REWARD_AMOUNT } from '@/config';
import { HttpException } from '@/exceptions/HttpException';
import { Submission } from '@/interfaces/submission.interface';
import { thor } from '@/utils/connex';
import { Service } from 'typedi';
import { MugshotABI } from '@/utils/const/abi';
import { estimateGas } from '@/utils/gas';
import { buildTransaction, sendTransaction, signTransaction } from '@/utils/tx';
import { ethers } from 'ethers';
import { config } from '@repo/config-contract';

@Service()
export class ContractsService {
  public async registerSubmission(submission: Submission): Promise<void> {
    const method = MugshotABI.find(abi => abi.name === 'registerValidSubmission');

    const clause = thor
      .account(config.CONTRACT_ADDRESS)
      .method(method)
      .asClause(submission.address, `0x${ethers.parseEther(REWARD_AMOUNT).toString(16)}`);

    const gasResult = await estimateGas([clause], 0, ADMIN_ADDRESS);

    if (gasResult.reverted === true) throw new HttpException(500, `EcoEarn: Internal server error: ${gasResult.revertReason}`);

    const tx = signTransaction(buildTransaction([clause], gasResult.gas), ADMIN_PRIVATE_KEY);

    await sendTransaction(tx);
  }

  public async validateSubmission(submission: Submission): Promise<void> {
    const method = MugshotABI.find(abi => abi.name === 'isUserMaxSubmissionsReached');

    const res = await thor.account(config.CONTRACT_ADDRESS).method(method).call(submission.address);

    if (res.decoded[0] === true) throw new HttpException(409, `EcoEarn: Max submissions reached for this cycle`);
  }
}
