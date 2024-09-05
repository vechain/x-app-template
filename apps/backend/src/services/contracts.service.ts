import { HttpException } from '@/exceptions/HttpException';
import { Submission } from '@/interfaces/submission.interface';
import { ecoEarnContract } from '@/utils/thor';
import { Service } from 'typedi';
import * as console from 'node:console';
@Service()
export class ContractsService {
  public async registerSubmission(submission: Submission): Promise<boolean> {
    let isSuccess = false;
    try {
      const result = await (await ecoEarnContract.transact.registerValidSubmission(submission.address, 1000n)).wait();

      console.log('Result', result);
      isSuccess = !result.reverted;
    } catch (error) {
      console.log('Error', error);
    }

    return isSuccess;
  }

  public async validateSubmission(submission: Submission): Promise<void> {
    const isMaxSubmissionsReached = (await ecoEarnContract.read.isUserMaxSubmissionsReached(submission.address))[0];
    // const currentcyle = (await ecoEarnContract.read.getCurrentCycle())[0];
    // //
    // // await (await ecoEarnContract.transact.setNextCycle(2n)).wait();
    // //
    // // await (await ecoEarnContract.transact.setRewardsAmount(40000000n)).wait();
    // const rewards = (await ecoEarnContract.read.rewards(1n))[0];

    if (Boolean(isMaxSubmissionsReached) === true) throw new HttpException(409, `EcoEarn: Max submissions reached for this cycle`);
  }
}
