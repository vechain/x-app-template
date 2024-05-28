import { NETWORK_TYPE, NETWORK_URL } from '../config';
import { Driver, SimpleNet } from '@vechain/connex-driver';
import { genesisBlock } from './network';
import { toNetwork } from './model';
import { newThor } from '@vechain/connex-framework/dist/thor';

export const driver = new Driver(new SimpleNet(NETWORK_URL), genesisBlock(toNetwork(NETWORK_TYPE)));

export const thor = newThor(driver);
