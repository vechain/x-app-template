import { Injectable } from '@nestjs/common';
import { Framework } from '@vechain/connex-framework';
import { Driver, SimpleNet } from '@vechain/connex-driver';
import * as crypto from 'crypto';

@Injectable()
export class VeChainService {
  private connex: Framework;
  private driver: Driver;
  private network: string;
  
  // Fixed accounts for consistent development and testing
  private adminWallet: {
    address: string;
    privateKey: string;
  };
  private treasuryWallet: {
    address: string;
    privateKey: string;
  };
  private distributorWallet: {
    address: string;
    privateKey: string;
  };

  // Contract ABI and address
  private readonly rewardsPoolAddress = '0x5F8f86B8D0Fa93cdaE20936d150175dF0205fB38';

  constructor() {
    // Determine which VeChain network to use
    this.network = process.env.VECHAIN_NETWORK || 'testnet';
    
    // Initialize wallet accounts
    this.initializeAccounts();
    
    // Initialize VeChain connection
    this.initializeConnex();
  }

  /**
   * Initialize VeChain Connex framework
   */
  private async initializeConnex(): Promise<void> {
    try {
      // Select network URL based on environment
      let url = 'https://testnet.veblockchain.com/';
      if (this.network === 'mainnet') {
        url = 'https://mainnet.veblockchain.com/';
      } else if (this.network === 'solo') {
        url = 'http://localhost:8669/';
      }

      // Create a Connex driver using SimpleNet
      this.driver = await Driver.connect(new SimpleNet(url));
      
      // Create Connex framework instance
      this.connex = new Framework(this.driver);
      
      console.log(`Connected to VeChain ${this.network} at ${url}`);
    } catch (error) {
      console.error('Failed to initialize VeChain connection:', error);
    }
  }

  /**
   * Initialize wallet accounts for testing
   * In a production environment, these would be loaded from secure environment variables
   */
  private initializeAccounts(): void {
    // For development and testing, we're using predefined accounts
    // Replace these with your own accounts for real usage
    
    // Admin account (replace with your own)
    this.adminWallet = {
      address: '0x7eF0CbaDFc0d1a4eC59F2D205Ad71258382FE3F4',
      privateKey: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
    };
    
    // Treasury account (replace with your own)
    this.treasuryWallet = {
      address: '0x3495D21A336B2D773Fe7DC9Bd6AfbE4a561fBF1C',
      privateKey: 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210'
    };
    
    // Distributor account (replace with your own)
    this.distributorWallet = {
      address: '0x60F73De462b0B20BB77730E26e42F5c4e60f4bf4',
      privateKey: 'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899'
    };
    
    console.log(`\n=== VECHAIN WALLET INFORMATION FOR DEVELOPMENT ===`);
    console.log(`ADMIN WALLET:`);
    console.log(`  Address: ${this.adminWallet.address}`);
    
    console.log(`\nTREASURY WALLET:`);
    console.log(`  Address: ${this.treasuryWallet.address}`);
    
    console.log(`\nDISTRIBUTOR WALLET:`);
    console.log(`  Address: ${this.distributorWallet.address}`);
    console.log(`================================================\n`);
    
    console.warn(`WARNING: Using hardcoded wallet addresses and private keys for development!`);
    console.warn(`DO NOT use these accounts for production or store real funds in them.`);
  }

  /**
   * Get the admin account address
   * @returns The admin wallet address
   */
  getAdminAddress(): string {
    return this.adminWallet.address;
  }

  /**
   * Get the treasury account address
   * @returns The treasury wallet address
   */
  getTreasuryAddress(): string {
    return this.treasuryWallet.address;
  }

  /**
   * Get the distributor account address
   * @returns The distributor wallet address
   */
  getDistributorAddress(): string {
    return this.distributorWallet.address;
  }

  /**
   * Generate a VeChain-compatible merkle proof for testing purposes
   * @param recipientAddress The address of the recipient for which to generate a proof
   * @returns A mock merkle proof as an array of 32-byte hex strings
   */
  generateMockProof(recipientAddress: string = ''): string[] {
    // Generate bytes32 using standard crypto library
    const generateBytes32 = (input: string): string => {
      const hash = crypto.createHash('sha256').update(input).digest('hex');
      return '0x' + hash;
    };

    // Create deterministic hash based on the recipient address
    const addressHash = recipientAddress 
      ? generateBytes32(recipientAddress)
      : generateBytes32(this.distributorWallet.address + Date.now());

    // Create deterministic proof elements
    const proofElement1 = generateBytes32(this.adminWallet.address + addressHash.slice(2));
    const proofElement2 = generateBytes32(this.treasuryWallet.address + addressHash.slice(2));

    return [proofElement1, proofElement2];
  }

  /**
   * Distributes reward to a user using VeChain's Connex transaction system
   * @param appId The application ID
   * @param recipient The address of the reward recipient
   * @param amount The amount of reward to distribute (in wei)
   * @param proof The merkle proof for verification
   * @returns Transaction hash if successful
   */
  async distributeReward(appId: string, recipient: string, amount: string, proof: string[]): Promise<string> {
    try {
      // Create a transaction clause using VeChain's Connex framework
      const clause = this.connex.thor.account(this.rewardsPoolAddress)
        .method({
          name: 'distributeRewardWithProof',
          inputs: [
            { name: 'appId', type: 'string' },
            { name: 'recipient', type: 'address' },
            { name: 'amount', type: 'uint256' },
            { name: 'proof', type: 'bytes32[]' }
          ],
          outputs: [{ name: '', type: 'bool' }]
        })
        .asClause(appId, recipient, amount, proof);

      // Get the private key to sign with (from environment or use distributor)
      // Remove '0x' prefix if present since VeChain signer expects no prefix
      const privateKey = process.env.PRIVATE_KEY || this.distributorWallet.privateKey.replace(/^0x/, '');

      // Sign and send the transaction using VeChain's transaction model
      const signingService = this.connex.vendor.sign('tx', [clause]);
      const result = await signingService.signer(privateKey).request();
      
      console.log(`VeChain transaction successful with hash: ${result.txid}`);
      return result.txid;
    } catch (error) {
      console.error('Error distributing reward on VeChain:', error);
      throw new Error(`Failed to distribute reward on VeChain: ${error.message}`);
    }
  }
}
