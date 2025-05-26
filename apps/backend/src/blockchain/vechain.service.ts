import { Injectable, OnModuleInit } from '@nestjs/common';
import {
 ProviderInternalBaseWallet,
 ThorClient,
 VeChainProvider,
 VeChainSigner,
} from '@vechain/sdk-network';
import { X2EarnRewardsPool } from '@vechain/vebetterdao-contracts';
import * as crypto from 'crypto';
import * as dotenv from 'dotenv';
import { Address } from '@vechain/sdk-core';

dotenv.config();

@Injectable()
export class VeChainService implements OnModuleInit {
 private thor: ThorClient;
 private provider: VeChainProvider;
 private rootSigner: VeChainSigner | null;
 private x2EarnRewardsPoolContract: any;
 // Store account info for admin, treasury, distributor
 private adminAccount: { address: string; privateKey: string };
 private treasuryAccount: { address: string; privateKey: string };
 private distributorAccount: { address: string; privateKey: string };
 constructor() {
   const nodeUrl = process.env.VECHAIN_RPC_URL || 'https://testnet.vechain.org';
   this.thor = ThorClient.at(nodeUrl);
   // Hardcoded keys for admin/treasury (for dev/testing only)
   const adminPrivateKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
   const treasuryPrivateKey = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
   const distributorPrivateKey = process.env.PRIVATE_KEY || 'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899';
   // Use SDK to derive addresses
   this.adminAccount = {
     privateKey: adminPrivateKey,
address: Address.ofPrivateKey(Buffer.from(adminPrivateKey, 'hex')).toString(),   };
   this.treasuryAccount = {
     privateKey: treasuryPrivateKey,
address: Address.ofPrivateKey(Buffer.from(treasuryPrivateKey, 'hex')).toString(),   };
   this.distributorAccount = {
     privateKey: distributorPrivateKey,
address: Address.ofPrivateKey(Buffer.from(distributorPrivateKey, 'hex')).toString(),   };
   this.provider = new VeChainProvider(
     this.thor,
     new ProviderInternalBaseWallet([
       {
         privateKey: Buffer.from(distributorPrivateKey, 'hex'),
         address: this.distributorAccount.address,
       },
     ])
   );
 }

 
 async onModuleInit() {
   this.rootSigner = await this.provider.getSigner();
   if (!this.rootSigner) throw new Error('Signer not initialized');
   this.x2EarnRewardsPoolContract = this.thor.contracts.load(
     process.env.X2EARN_REWARDS_POOL_ADDRESS || '0x5F8f86B8D0Fa93cdaE20936d150175dF0205fB38',
     X2EarnRewardsPool.abi,
     this.rootSigner
);
 }
 // Distribute reward using the contract
 async distributeReward(
   appId: string,
   recipient: string,
   amount: number,
   proof: string[]
 ): Promise<string> {
   if (!this.x2EarnRewardsPoolContract) throw new Error('Contract not initialized');
   const tx = await this.x2EarnRewardsPoolContract.transact.distributeRewardWithProof(
     appId,
     recipient,
     amount,
     proof
   );
   await tx.wait();
   return tx.txid;
 }
 // Utility: Get admin address
 getAdminAddress(): string {
   return this.adminAccount.address;
 }
 // Utility: Get treasury address
 getTreasuryAddress(): string {
   return this.treasuryAccount.address;
 }
 // Utility: Get distributor address
 getDistributorAddress(): string {
   return this.distributorAccount.address;
 }
 // Utility: Generate a mock proof (for testing)
 generateMockProof(recipientAddress: string = ''): string[] {
   const generateBytes32 = (input: string): string => {
     const hash = crypto.createHash('sha256').update(input).digest('hex');
     return '0x' + hash;
   };
   const addressHash = recipientAddress
     ? generateBytes32(recipientAddress)
     : generateBytes32(this.distributorAccount.address + Date.now().toString());
   const proofElement1 = generateBytes32(this.adminAccount.address + addressHash.slice(2));
   const proofElement2 = generateBytes32(this.treasuryAccount.address + addressHash.slice(2));
   return [proofElement1, proofElement2];
 }
}