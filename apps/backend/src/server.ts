import { App } from '@/app';
import { initializeOpenAI } from './utils/initializeOpenAI';
import { SubmissionRoute } from './routes/submission.route';

export const openAIHelper = initializeOpenAI();

const app = new App([new SubmissionRoute()]);

app.listen();
