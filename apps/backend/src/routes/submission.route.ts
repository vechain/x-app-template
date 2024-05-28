import { Router } from 'express';
import { Routes } from '@interfaces/routes.interface';
import { SubmissionController } from '@/controllers/submission.controller';
import { ValidationMiddleware } from '@/middlewares/validation.middleware';
import { SubmitDto } from '@/dtos/submission.dto';

export class SubmissionRoute implements Routes {
  public router = Router();
  public submission = new SubmissionController();

  constructor() {
    this.initializeRoutes();
  }

  private initializeRoutes() {
    this.router.post(`/submitReceipt`, ValidationMiddleware(SubmitDto), this.submission.submitReceipt);
  }
}
