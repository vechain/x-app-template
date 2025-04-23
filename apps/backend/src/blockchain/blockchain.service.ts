import { Injectable } from '@nestjs/common';
import Web3 from 'web3';
import thorify from 'thorify';
import { recover, mnemonicToPrivateKey } from '@vechain/thor-devkit';
import * as dotenv from 'dotenv';

dotenv.config();

@Injectable()
export class BlockchainService {
  private readonly web3: Web3;
  private readonly rewardsPoolContract: any;

  private readonly adminPrivateKey: string;
  private readonly treasuryPrivateKey: string;
  private readonly distributorPrivateKey: string;

  constructor() {
    const rpcUrl = process.env.VECHAIN_RPC_URL || 'https://mainnet.veblocks.net';
    
    // Thorify enhances Web3 to work with Vechain
    const thor = thorify(new Web3(), rpcUrl);
    this.web3 = thor;

    // Load private keys from env or mnemonic
    this.adminPrivateKey = this.getPrivateKeyFromMnemonic(process.env.ADMIN_MNEMONIC!);
    this.treasuryPrivateKey = this.getPrivateKeyFromMnemonic(process.env.TREASURY_MNEMONIC!);
    this.distributorPrivateKey = this.getPrivateKeyFromMnemonic(process.env.DISTRIBUTOR_MNEMONIC!);

    const contractAbi = [
      {
        "constant": false,
        "inputs": [
          { "name": "appId", "type": "string" },
          { "name": "recipient", "type": "address" },
          { "name": "amount", "type": "uint256" },
          { "name": "proof", "type": "bytes32[]" }
        ],
        "name": "distributeRewardWithProof",
        "outputs": [{ "name": "", "type": "bool" }],
        "type": "function"
      }
    ];

    const contractAddress = '0x5F8f86B8D0Fa93cdaE20936d150175dF0205fB38';
    this.rewardsPoolContract = new this.web3.eth.Contract(contractAbi as any, contractAddress);
  }

  private getPrivateKeyFromMnemonic(mnemonic: string): string {
    const wallet = mnemonicToPrivateKey(mnemonic);
    return `0x${wallet.toString('hex')}`;
  }

  async distributeReward(appId: string, recipient: string, amount: string, proof: string[]): Promise<string> {
    try {
      const fromAddress = this.web3.eth.accounts.privateKeyToAccount(this.distributorPrivateKey).address;
      const amountInWei = this.web3.utils.toWei(amount, 'ether');

      const txData = this.rewardsPoolContract.methods
        .distributeRewardWithProof(appId, recipient, amountInWei, proof)
        .encodeABI();

      const tx = {
        from: fromAddress,
        to: this.rewardsPoolContract.options.address,
        data: txData,
        gas: 2000000
      };

      const signed = await this.web3.eth.accounts.signTransaction(tx, this.distributorPrivateKey);
      const receipt = await this.web3.eth.sendSignedTransaction(signed.rawTransaction!);

      console.log('Tx Hash:', receipt.transactionHash);
      return receipt.transactionHash;
    } catch (error) {
      console.error('Transaction error:', error);
      throw new Error(`Failed to send transaction: ${error.message}`);
    }
  }

  generateMockProof(recipientAddress: string): string[] {
    const hash = this.web3.utils.soliditySha3({ type: 'address', value: recipientAddress })!;
    const dummy1 = this.web3.utils.soliditySha3(hash + '1')!;
    const dummy2 = this.web3.utils.soliditySha3(hash + '2')!;
    return [dummy1, dummy2];
  }

  getAdminAddress(): string {
    return this.web3.eth.accounts.privateKeyToAccount(this.adminPrivateKey).address;
  }

  getTreasuryAddress(): string {
    return this.web3.eth.accounts.privateKeyToAccount(this.treasuryPrivateKey).address;
  }

  getDistributorAddress(): string {
    return this.web3.eth.accounts.privateKeyToAccount(this.distributorPrivateKey).address;
  }
}
