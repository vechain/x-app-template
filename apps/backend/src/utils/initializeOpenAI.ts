import { OpenAIHelper } from '@/services/helpers';

export const initializeOpenAI = () => {
  return new OpenAIHelper();
};
