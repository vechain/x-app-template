import { config } from 'dotenv';
import { mnemonic } from '@vechain/sdk-core';
config({ path: `.env.${process.env.NODE_ENV || 'development'}.local` });

export const CREDENTIALS = process.env.CREDENTIALS === 'true';
export const { NODE_ENV, PORT, LOG_FORMAT, LOG_DIR, ORIGIN } = process.env;
export const { OPENAI_API_KEY } = process.env;
export const { MAX_FILE_SIZE } = process.env;
export const { ADMIN_MNEMONIC, ADMIN_ADDRESS } = process.env;
export const { NETWORK_URL, NETWORK_TYPE } = process.env;
export const { RECAPTCHA_SECRET_KEY } = process.env;
export const { REWARD_AMOUNT } = process.env;

export const ADMIN_PRIVATE_KEY = mnemonic.derivePrivateKey(ADMIN_MNEMONIC.split(' '));
