import { NextFunction, Request, Response } from 'express';
import { Container } from 'typedi';
import { OpenaiService } from '@/services/openai.service';
import { Submission } from '@/interfaces/submission.interface';
import { HttpException } from '@/exceptions/HttpException';
import { ContractsService } from '@/services/contracts.service';

export class SubmissionController {
  public openai = Container.get(OpenaiService);
  public contracts = Container.get(ContractsService);

  public submitReceipt = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const body: Omit<Submission, 'timestamp'> = req.body;

      const submissionRequest: Submission = {
        ...body,
        timestamp: Date.now(),
      };
      // Submission validation with smart contract
      await this.contracts.validateSubmission(submissionRequest);

      const validationResult = await this.openai.validateImage(body.image);

      if (validationResult == undefined || !('validityFactor' in (validationResult as object))) {
        throw new HttpException(500, 'Error validating image');
      }

      const validityFactor = validationResult['validityFactor'];

      if (validityFactor === 1) {
        const result = await this.contracts.registerSubmission(submissionRequest);
      }

      res.status(200).json({ validation: validationResult });
    } catch (error) {
      next(error);
      return;
    }
  };
}
