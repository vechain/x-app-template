import { Service } from 'typedi';
import { verifyCaptchaURL } from './helpers';
import { RECAPTCHA_SECRET_KEY } from '@/config';
import axios from 'axios';

@Service()
export class CaptchaService {
  public async validateCaptcha(token: string): Promise<boolean> {
    const verifyURL = verifyCaptchaURL(token, RECAPTCHA_SECRET_KEY);

    try {
      const response = await axios.post(verifyURL);
      return response.data.success;
    } catch (error) {
      console.error(error);
      return false;
    }
  }
}
