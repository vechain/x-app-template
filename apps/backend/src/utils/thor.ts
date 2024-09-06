import { ADMIN_PRIVATE_KEY, NETWORK_URL } from '../config';
import { HttpClient, ThorClient, VeChainPrivateKeySigner, VeChainProvider } from '@vechain/sdk-network';
import { EcoEarnABI } from '@utils/const';
import { ECO_SOL_ABI, config } from '@repo/config-contract';

export const thor = new ThorClient(new HttpClient(NETWORK_URL), {
  isPollingEnabled: false,
});

export const ecoEarnContract = thor.contracts.load(
  config.CONTRACT_ADDRESS,
  ECO_SOL_ABI,
  new VeChainPrivateKeySigner(Buffer.from(ADMIN_PRIVATE_KEY), new VeChainProvider(thor)),
);
