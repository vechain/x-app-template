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

      if (!response.data.success) return false;
      if (response.data.action !== 'submit_receipt') return false;
      if (response.data.score < 0.7) return false;

      return true;
    } catch (error) {
      console.error(error);
      return false;
    }
  }
}
