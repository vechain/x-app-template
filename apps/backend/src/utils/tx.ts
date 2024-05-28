import { Transaction, secp256k1 } from 'thor-devkit';
import { thor } from './connex';
import { Clause } from './model';
import { randomBytes } from 'crypto';
import { addPrefix, toHexString } from './hex';
import axios, { AxiosError } from 'axios';
import { NETWORK_URL } from '../config';
import { logger } from './logger';
import { HttpException } from '../exceptions/HttpException';

export const buildTransaction = (clauses: Clause[], gas: number): Transaction => {
  const txBody: Transaction.Body = {
    chainTag: parseInt(thor.genesis.id.slice(-2), 16),
    blockRef: thor.status.head.id.slice(0, 18),
    // 5 minutes
    expiration: 30,
    clauses: clauses,
    gasPriceCoef: 127,
    gas,
    dependsOn: null,
    nonce: `0x${toHexString(randomBytes(8))}`,
  };

  return new Transaction(txBody);
};

export const signTransaction = (tx: Transaction, privateKey: Buffer): Transaction => {
  tx.signature = secp256k1.sign(tx.signingHash(), privateKey);

  return tx;
};

export const sendTransaction = async (signedTransaction: Transaction): Promise<void> => {
  const encodedRawTx = {
    raw: addPrefix(signedTransaction.encode().toString('hex')),
  };

  try {
    await axios.post(`${NETWORK_URL}/transactions`, encodedRawTx);
  } catch (e) {
    if (e instanceof AxiosError) {
      logger.error('Error sending transaction', e.toJSON());
    }

    throw new HttpException(500, 'Internal server error');
  }
};
