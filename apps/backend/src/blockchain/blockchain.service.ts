import { Injectable } from '@nestjs/common';
import { 
  JsonRpcProvider, 
  Contract, 
  Wallet,
  HDNodeWallet,
  parseEther,
  randomBytes,
  hexlify,
  keccak256,
  toUtf8Bytes,
  concat
} from 'ethers';

@Injectable()
export class BlockchainService {
  private readonly provider: JsonRpcProvider;
  private readonly rewardsPoolContract: any; 
  private readonly signer: Wallet | HDNodeWallet;
  
  // Fixed accounts for consistent development and testing
  private adminWallet: Wallet | HDNodeWallet;
  private treasuryWallet: Wallet | HDNodeWallet;
  private distributorWallet: Wallet | HDNodeWallet;

  // ABI for the X2EarnRewardsPool contract's distributeRewardWithProof function
  private readonly rewardsPoolAbi = [
    'function distributeRewardWithProof(string appId, address recipient, uint256 amount, bytes32[] calldata proof) external returns (bool)'
  ];

  constructor() {
    // Initialize provider - update RPC URL as needed
    this.provider = new JsonRpcProvider(
      process.env.VECHAIN_RPC_URL || 'https://mainnet.veblockchain.com'
    );

    // Generate deterministic accounts for testing
    this.initializeAccounts();

    // Initialize contract with the provided address
    this.rewardsPoolContract = new Contract(
      '0x5F8f86B8D0Fa93cdaE20936d150175dF0205fB38', 
      this.rewardsPoolAbi,
      this.provider
    );

    // Use environment variable for private key (NEVER hardcode private keys)
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
      console.warn('Warning: No private key provided. Using distributor wallet as signer.');
      // Use the distributor wallet if no private key is available
      this.signer = this.distributorWallet;
    } else {
      this.signer = new Wallet(privateKey, this.provider);
    }
    
    // Connect contract to signer for transactions
    this.rewardsPoolContract = this.rewardsPoolContract.connect(this.signer);
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
    const adminMnemonic = 'add your wallet here';
    const treasuryMnemonic = 'add your wallet here';
    const distributorMnemonic = 'add your wallet here';
    
    // Derive wallets from mnemonics
    this.adminWallet = HDNodeWallet.fromPhrase(adminMnemonic).connect(this.provider);
    this.treasuryWallet = HDNodeWallet.fromPhrase(treasuryMnemonic).connect(this.provider);
    this.distributorWallet = HDNodeWallet.fromPhrase(distributorMnemonic).connect(this.provider);
    
    console.log(`\n=== WALLET INFORMATION FOR DEVELOPMENT ===`);
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
    console.log(`=========================================\n`);
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
   * Distributes reward to a user if AI validation passes
   * @param appId The application ID
   * @param recipient The address of the reward recipient
   * @param amount The amount of reward to distribute
   * @param proof The merkle proof for verification
   * @returns Transaction hash if successful
   */
  async distributeReward(appId: string, recipient: string, amount: string, proof: string[]): Promise<string> {
    try {
      // Convert amount to Wei (assuming amount is in Ether)
      const amountInWei = parseEther(amount);

      // Call the contract function
      const tx = await this.rewardsPoolContract.distributeRewardWithProof(
        appId,
        recipient,
        amountInWei,
        proof
      );

      // Wait for transaction to be mined
      const receipt = await tx.wait();
      console.log(`Transaction successful with hash: ${receipt.hash}`);
      
      return receipt.hash;
    } catch (error) {
      console.error('Error distributing reward:', error);
      throw new Error(`Failed to distribute reward: ${error.message}`);
    }
  }

  /**
   * Generate a mock merkle proof for testing purposes
   * In a real application, this would be generated based on a real merkle tree
   * @param recipientAddress The address of the recipient for which to generate a proof
   * @returns A mock merkle proof as an array of 32-byte hex strings
   */
  generateMockProof(recipientAddress: string = ''): string[] {
    // In a real implementation, you would create a merkle tree with all eligible addresses 
    // and generate a proper proof for the specific recipient address
    // Here we're just creating a simple deterministic mock proof

    // Create a deterministic hash based on the recipient address
    const addressHash = recipientAddress 
      ? keccak256(toUtf8Bytes(recipientAddress))
      : keccak256(toUtf8Bytes(this.distributorWallet.address + Date.now()));

    // Create deterministic proof elements
    const proofElement1 = keccak256(
      concat([
        toUtf8Bytes(this.adminWallet.address),
        addressHash
      ])
    );
    
    const proofElement2 = keccak256(
      concat([
        toUtf8Bytes(this.treasuryWallet.address),
        addressHash
      ])
    );

    return [proofElement1, proofElement2];
  }
}
