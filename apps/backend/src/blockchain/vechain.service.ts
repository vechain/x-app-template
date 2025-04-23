import { Injectable } from '@nestjs/common';
import { Wallet, HDNodeWallet } from 'ethers';
import { Framework } from '@vechain/connex-framework';
import { Driver, SimpleNet } from '@vechain/connex-driver';

@Injectable()
export class VeChainService {
  private connex: Framework;
  private driver: Driver;
  private network: string;
  
  // Fixed accounts for consistent development and testing
  private adminWallet: Wallet | HDNodeWallet;
  private treasuryWallet: Wallet | HDNodeWallet;
  private distributorWallet: Wallet | HDNodeWallet;

  // Contract ABI and address
  private readonly rewardsPoolAddress = '0x5F8f86B8D0Fa93cdaE20936d150175dF0205fB38';
  private readonly rewardsPoolAbi = [
    'function distributeRewardWithProof(string appId, address recipient, uint256 amount, bytes32[] calldata proof) external returns (bool)'
  ];

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
   * Initialize the admin, treasury, and distributor accounts
   * These are deterministic wallets derived from mnemonics for development purposes
   * In production, you would use secure private keys from environment variables
   */
  private initializeAccounts(): void {
    // Real mnemonic phrases that generate usable wallets
    // WARNING: These are now publicly visible in the codebase
    // Only use these for testing and development, not for real funds
    const adminMnemonic = 'uphold lounge dust elegant crisp pepper cup police ladder nest more alert';
    const treasuryMnemonic = 'fatal mercy remove captain tired ancient gaze side appear teach group squeeze';
    const distributorMnemonic = 'divide cruise upon flag settle easy chair clarify melody popular child flame';
    
    // Derive wallets from mnemonics
    // Note: While we're using ethers.js for wallet generation,
    // the addresses and private keys are compatible with VeChain's format
    this.adminWallet = HDNodeWallet.fromPhrase(adminMnemonic);
    this.treasuryWallet = HDNodeWallet.fromPhrase(treasuryMnemonic);
    this.distributorWallet = HDNodeWallet.fromPhrase(distributorMnemonic);
    
    console.log(`\n=== VECHAIN WALLET INFORMATION FOR DEVELOPMENT ===`);
    console.log(`ADMIN WALLET:`);
    console.log(`  Address: ${this.adminWallet.address}`);
    console.log(`  Mnemonic: ${adminMnemonic}`);
    console.log(`  Private Key: ${this.adminWallet.privateKey}`);
    
    console.log(`\nTREASURY WALLET:`);
    console.log(`  Address: ${this.treasuryWallet.address}`);
    console.log(`  Mnemonic: ${treasuryMnemonic}`);
    console.log(`  Private Key: ${this.treasuryWallet.privateKey}`);
    
    console.log(`\nDISTRIBUTOR WALLET:`);
    console.log(`  Address: ${this.distributorWallet.address}`);
    console.log(`  Mnemonic: ${distributorMnemonic}`);
    console.log(`  Private Key: ${this.distributorWallet.privateKey}`);
    console.log(`================================================\n`);
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
    // Create a helper function to generate a deterministic bytes32 value
    const generateBytes32 = (input: string): string => {
      // Simple hash function that produces a deterministic 32-byte hex string
      let result = '';
      let hash = 0;
      
      // Generate a hash of the input string
      for (let i = 0; i < input.length; i++) {
        hash = ((hash << 5) - hash) + input.charCodeAt(i);
        hash = hash & hash; // Convert to 32bit integer
      }
      
      // Create a hex string from the hash value
      const hexHash = Math.abs(hash).toString(16);
      
      // Pad to ensure 32 bytes (64 hex chars) and add 0x prefix
      result = '0x' + hexHash.padStart(64, '0');
      
      return result;
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
