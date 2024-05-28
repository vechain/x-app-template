import { NextFunction, Request, Response } from 'express';
import { logger } from '@utils/logger';
import { HttpException } from '@/exceptions/HttpException';

export const ErrorMiddleware = (error: HttpException, req: Request, res: Response, next: NextFunction) => {
  try {
    const status: number = error.status || 500;
    const message: string = error.message || 'Something went wrong';

    logger.error(`[${req.method}] ${req.path} >> StatusCode:: ${status}, Message:: ${message}`);

    if (process.env.NODE_ENV === 'production') {
      res.status(status).json({
        message,
      });
    } else {
      res.status(status).json({
        message,
        stack: error.stack,
      });
    }
  } catch (error) {
    next(error);
  }
};
