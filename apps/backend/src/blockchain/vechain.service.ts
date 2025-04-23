import { Injectable } from '@nestjs/common';
import * as crypto from 'crypto';
import { 
  Address 
} from '@vechain/sdk-core';

// For direct HTTP requests to the VeChain node
import * as http from 'http';
import * as https from 'https';

@Injectable()
export class VeChainService {
  // Fixed accounts for consistent development and testing
  private adminAccount: { address: string; privateKey: string; };
  private treasuryAccount: { address: string; privateKey: string; };
  private distributorAccount: { address: string; privateKey: string; };

  // VeChain node URL and network
  private veChainNodeUrl: string;
  private networkType: string;

  // Contract address and ABI for X2EarnRewardsPool
  private readonly rewardsPoolAddress = '0x5F8f86B8D0Fa93cdaE20936d150175dF0205fB38';
  private readonly rewardsPoolABI = [
    {
      "inputs": [
        {
          "internalType": "string",
          "name": "appId",
          "type": "string"
        },
        {
          "internalType": "address",
          "name": "recipient",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "amount",
          "type": "uint256"
        },
        {
          "internalType": "bytes32[]",
          "name": "proof",
          "type": "bytes32[]"
        }
      ],
      "name": "distributeRewardWithProof",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ];

  constructor() {
    // Initialize VeChain connection details
    this.initializeVeChain();
    
    // Initialize wallet accounts
    this.initializeAccounts();
  }

  /**
   * Initialize VeChain connection
   */
  private initializeVeChain(): void {
    try {
      // Determine which VeChain network to use from environment or default to testnet
      this.networkType = process.env.VECHAIN_NETWORK || 'testnet';
      
      // Set the node URL based on network type
      if (this.networkType === 'mainnet') {
        this.veChainNodeUrl = 'https://mainnet.veblockchain.com';
      } else if (this.networkType === 'testnet') {
        this.veChainNodeUrl = 'https://testnet.veblockchain.com';
      } else if (this.networkType === 'solo' || this.networkType === 'local') {
        this.veChainNodeUrl = 'http://localhost:8669';
      } else {
        this.veChainNodeUrl = 'https://testnet.veblockchain.com';
      }
      
      console.log(`VeChain connection set to: ${this.veChainNodeUrl} (${this.networkType})`);
      
      // Test the connection by making a direct request to the node
      this.testConnection();
      
    } catch (error) {
      console.error('Failed to initialize VeChain connection:', error);
    }
  }

  /**
   * Test the connection to the VeChain node
   */
  private async testConnection(): Promise<void> {
    try {
      const response = await this.makeRequest('/blocks/best');
      console.log(`Successfully connected to VeChain ${this.networkType} at block #${response.number}`);
    } catch (error) {
      console.error('Error testing connection to VeChain node:', error);
    }
  }

  /**
   * Make an HTTP request to the VeChain node
   * @param path The API path
   * @param method The HTTP method
   * @param data The request data
   * @returns The response data
   */
  private makeRequest(path: string, method: string = 'GET', data?: any): Promise<any> {
    return new Promise((resolve, reject) => {
      const isHttps = this.veChainNodeUrl.startsWith('https');
      const url = new URL(path, this.veChainNodeUrl);
      
      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname + url.search,
        method: method,
        headers: {
          'Content-Type': 'application/json',
        }
      };
      
      const req = (isHttps ? https : http).request(options, (res) => {
        let responseData = '';
        
        res.on('data', (chunk) => {
          responseData += chunk;
        });
        
        res.on('end', () => {
          try {
            const parsedData = JSON.parse(responseData);
            resolve(parsedData);
          } catch (error) {
            reject(new Error(`Failed to parse response: ${error.message}`));
          }
        });
      });
      
      req.on('error', (error) => {
        reject(new Error(`Request failed: ${error.message}`));
      });
      
      if (data) {
        req.write(JSON.stringify(data));
      }
      
      req.end();
    });
  }

  /**
   * Initialize wallet accounts for testing
   */
  private initializeAccounts(): void {
    // For development and testing purposes, hardcoded keys
    const adminPrivateKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const treasuryPrivateKey = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
    // Use the PRIVATE_KEY env var if available, otherwise fall back to a default
    const distributorPrivateKey = process.env.PRIVATE_KEY || 'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899';
    
    // Create accounts with addresses
    this.adminAccount = {
      privateKey: adminPrivateKey,
      address: this.generateAddress(adminPrivateKey)
    };
    
    this.treasuryAccount = {
      privateKey: treasuryPrivateKey,
      address: this.generateAddress(treasuryPrivateKey)
    };
    
    this.distributorAccount = {
      privateKey: distributorPrivateKey,
      address: this.generateAddress(distributorPrivateKey)
    };
    
    console.log(`\n=== VECHAIN ACCOUNT INFORMATION FOR DEVELOPMENT ===`);
    console.log(`ADMIN ACCOUNT:`);
    console.log(`  Address: ${this.adminAccount.address}`);
    
    console.log(`\nTREASURY ACCOUNT:`);
    console.log(`  Address: ${this.treasuryAccount.address}`);
    
    console.log(`\nDISTRIBUTOR ACCOUNT (USED FOR SIGNING TRANSACTIONS):`);
    console.log(`  Address: ${this.distributorAccount.address}`);
    console.log(`================================================\n`);
    
    console.warn(`WARNING: Using hardcoded private keys for development!`);
    console.warn(`DO NOT use these accounts for production or store real funds in them.`);
  }

  /**
   * Generate an address from a private key
   * For simplicity, this is a placeholder implementation
   */
  private generateAddress(privateKeyHex: string): string {
    // For development, just return a deterministic address based on the private key
    // In production, use VeChain's proper tools
    return `0x${privateKeyHex.slice(0, 40)}`;
  }

  /**
   * Get the admin account address
   */
  getAdminAddress(): string {
    return this.adminAccount.address;
  }

  /**
   * Get the treasury account address
   */
  getTreasuryAddress(): string {
    return this.treasuryAccount.address;
  }

  /**
   * Get the distributor account address
   */
  getDistributorAddress(): string {
    return this.distributorAccount.address;
  }

  /**
   * Generate a VeChain-compatible merkle proof
   * @param recipientAddress The address of the recipient for which to generate a proof
   * @returns A merkle proof as an array of 32-byte hex strings
   */
  generateMockProof(recipientAddress: string = ''): string[] {
    // Generate bytes32 using crypto for hashing
    const generateBytes32 = (input: string): string => {
      const hash = crypto.createHash('sha256').update(input).digest('hex');
      return '0x' + hash;
    };

    // Create deterministic hash based on the recipient address
    const addressHash = recipientAddress 
      ? generateBytes32(recipientAddress)
      : generateBytes32(this.distributorAccount.address + Date.now().toString());

    // Create deterministic proof elements
    const proofElement1 = generateBytes32(this.adminAccount.address + addressHash.slice(2));
    const proofElement2 = generateBytes32(this.treasuryAccount.address + addressHash.slice(2));

    return [proofElement1, proofElement2];
  }

  /**
   * Encode a function call for distributeRewardWithProof
   */
  private encodeFunctionCall(funcName: string, params: any[]): string {
    // This is a simplified function selector and ABI encoding for development
    // In production, use the proper VeChain SDK for ABI encoding
    
    // Create a simple function selector by hashing the signature
    const signature = `${funcName}(string,address,uint256,bytes32[])`;
    const selector = '0x' + crypto.createHash('sha256').update(signature).digest('hex').slice(0, 8);
    
    // For now, just return the selector to indicate what we're calling
    // In production, this would include properly encoded parameters
    return selector;
  }

  /**
   * Distributes reward to a user using VeChain HTTP API
   * @param appId The application ID
   * @param recipient The address of the reward recipient
   * @param amount The amount of reward to distribute (in wei)
   * @param proof The merkle proof for verification
   * @returns Transaction hash if successful
   */
  async distributeReward(appId: string, recipient: string, amount: string, proof: string[]): Promise<string> {
    try {
      console.log(`\nPreparing VeChain transaction:`);
      console.log(`  Network: ${this.networkType}`);
      console.log(`  Contract: ${this.rewardsPoolAddress}`);
      console.log(`  Method: distributeRewardWithProof`);
      console.log(`  App ID: ${appId}`);
      console.log(`  Recipient: ${recipient}`);
      console.log(`  Amount: ${amount}`);
      console.log(`  Proof Elements: ${proof.length}`);
      
      // Generate transaction data (function selector only for now)
      const data = this.encodeFunctionCall('distributeRewardWithProof', [
        appId, recipient, amount, proof
      ]);
      
      // Prepare the transaction request body
      const txBody = {
        chainTag: this.networkType === 'mainnet' ? '0x4a' : '0x27', // Mainnet: 74, Testnet: 39
        blockRef: '0x00000000aabbccdd', // This would be fetched from the node in production
        expiration: 32,
        clauses: [
          {
            to: this.rewardsPoolAddress,
            value: '0x0',
            data: data
          }
        ],
        gasPriceCoef: 0,
        gas: 300000,
        dependsOn: null,
        nonce: Date.now().toString() // Use timestamp as nonce for development
      };
      
      console.log(`\nConnecting to VeChain node at: ${this.veChainNodeUrl}`);
      console.log(`Sending transaction using the VeChain Sync2 method...`);
      
      // In a real implementation, we would:
      // 1. Sign the transaction with the distributor's private key
      // 2. Send the transaction to the VeChain node
      // 3. Return the transaction ID
      
      // For development, generate a mock transaction ID
      const txId = '0x' + crypto.randomBytes(32).toString('hex');
      
      console.log(`\nVeChain transaction sent (simulated)!`);
      console.log(`Transaction ID: ${txId}`);
      console.log(`\nIMPORTANT: This is currently a simulated transaction.`);
      console.log(`In production, implement proper transaction signing and submission.`);
      
      return txId;
    } catch (error) {
      console.error('Error distributing reward on VeChain:', error);
      throw new Error(`Failed to distribute reward on VeChain: ${error.message}`);
    }
  }
}
