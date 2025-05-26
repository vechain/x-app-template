import { Injectable } from '@nestjs/common';
import { AIService } from '../ai/ai.service';
import { VeChainService } from '../blockchain/vechain.service';

@​Injectable()
export class UserService {
  constructor(
    private readonly aiService: AIService,
    private readonly veChainService: VeChainService,
  ) {}

  /*
   * Validate a claim using the AI service and distribute rewards if valid
   * @​param claimData The claim data to validate
   * @​returns The validation result and transaction hash if successful
   */
  async validateClaim(claimData: any): Promise<{
    isValid: boolean;
    transactionHash?: string;
    message: string;
  }> {
    try {
      // First validate the claim using the AI service
      const isValid = await this.aiService.validateClaim(claimData);

      if (!isValid) {
        return {
          isValid: false,
          message: 'Claim was rejected by AI validation',
        };
      }

      // If valid, distribute reward through the blockchain
      const {
        walletAddress,
        rewardAmount = '0.01',
        appId = '0x4b9109786611682e57aa4ecb52e9acae3c1c4adfe17bf5518820da766bd08396',
      } = claimData;

      if (!walletAddress) {
        return {
          isValid: true,
          message: 'Claim is valid but no wallet address provided for reward',
        };
      }

      // Generate mock proof for the specific recipient address
      const proof = this.veChainService.generateMockProof(walletAddress);

      // Convert amount to number of VET (the SDK and contract expect a number, not a string in wei)
      const amount = Number(rewardAmount);

      // Distribute reward
      const transactionHash = await this.veChainService.distributeReward(
        appId,
        walletAddress,
        amount,
        proof,
      );

      return {
        isValid: true,
        transactionHash,
        message: 'Claim validated and reward distributed successfully on VeChain',
      };
    } catch (error) {
      console.error('Error in claim validation process:', error);
      return {
        isValid: false,
        message: `Error processing claim: ${error.message}`,
      };
    }
  }
}