import { Injectable, OnModuleInit } from '@nestjs/common';
import {
  ProviderInternalHDWallet,
  ThorClient,
  VeChainProvider,
  VeChainSigner,
} from '@vechain/sdk-network';
import { X2EarnRewardsPool } from '@vechain/vebetterdao-contracts';
import * as dotenv from 'dotenv';

dotenv.config();

@Injectable()
export class BlockchainService implements OnModuleInit {
  private thor: ThorClient;
  private provider: VeChainProvider;
  private rootSigner: VeChainSigner | null = null;
  private x2EarnRewardsPoolContract: any = null;

  constructor() {
    const nodeUrl = process.env.VECHAIN_RPC_URL || 'https://mainnet.vechain.org';
    this.thor = ThorClient.at(nodeUrl);

    const mnemonic = process.env.DISTRIBUTOR_MNEMONIC?.split(' ') || [];
    this.provider = new VeChainProvider(
      this.thor,
      new ProviderInternalHDWallet(mnemonic)
    );
  }


async onModuleInit() {
  this.rootSigner = await this.provider.getSigner();

  // This check is not strictly necessary, but you can keep it for safety
  if (!this.rootSigner) {
    throw new Error('Signer not initialized');
  }

  this.x2EarnRewardsPoolContract = this.thor.contracts.load(
    process.env.X2EARN_REWARDS_POOL_ADDRESS || '',
    X2EarnRewardsPool.abi,
    this.rootSigner
  );
}

  async distributeReward(
    appId: string,
    recipient: string,
    amount: number,
    proofTypes: string[],
    proofUrls: string[],
    impactTypes: string[],
    impactValues: number[],
    description: string,
    metadata: object
  ): Promise<string> {
    if (!this.x2EarnRewardsPoolContract) {
      throw new Error('Contract not initialized yet');
    }

    const tx = await this.x2EarnRewardsPoolContract.transact.distributeRewardWithProofAndMetadata(
      appId,
      amount,
      recipient,
      proofTypes,
      proofUrls,
      impactTypes,
      impactValues,
      description,
      JSON.stringify(metadata)
    );

    await tx.wait();
    return tx.txid;
  }
}