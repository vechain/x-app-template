import { NETWORK_URL } from '../config';
import { HttpClient, ThorClient } from '@vechain/sdk-network';

export const thor = new ThorClient(new HttpClient(NETWORK_URL), {
  isPollingEnabled: false,
});
