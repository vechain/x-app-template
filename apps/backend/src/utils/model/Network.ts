export enum Network {
  solo = 'solo',
  testnet = 'testnet',
  mainnet = 'mainnet',
}

export const toNetwork = (network: string): Network => {
  switch (network) {
    case 'solo':
      return Network.solo;
    case 'testnet':
      return Network.testnet;
    case 'mainnet':
      return Network.mainnet;
    default:
      throw new Error(`Unknown network: ${network}`);
  }
};
