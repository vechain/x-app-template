import { App } from '@/app';
import { ValidateEnv } from '@utils/validateEnv';
import { initializeOpenAI } from './utils/initializeOpenAI';
import { SubmissionRoute } from './routes/submission.route';

ValidateEnv();

export const openAIHelper = initializeOpenAI();

const app = new App([new SubmissionRoute()]);

app.listen();
