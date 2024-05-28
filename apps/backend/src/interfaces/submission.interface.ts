export interface Submission {
  _id?: string;
  round?: number;
  address: string;
  captcha: string;
  timestamp: number;
  image?: string;
  deviceID?: string;
}
