import { config } from 'dotenv';
import { mnemonic } from '@vechain/sdk-core';
import { ValidateEnv } from '@utils/validateEnv';
config({ path: `.env.${process.env.NODE_ENV || 'development'}.local` });

const validatedEnv = ValidateEnv();

export const CREDENTIALS = process.env.CREDENTIALS === 'true';
export const { NODE_ENV, PORT, LOG_FORMAT, LOG_DIR, ORIGIN } = validatedEnv;

export const { OPENAI_API_KEY } = validatedEnv;
export const { MAX_FILE_SIZE } = validatedEnv;
export const { ADMIN_MNEMONIC, ADMIN_ADDRESS } = validatedEnv;
export const { NETWORK_URL, NETWORK_TYPE } = validatedEnv;
export const { REWARD_AMOUNT } = validatedEnv;

export const ADMIN_PRIVATE_KEY = mnemonic.derivePrivateKey(ADMIN_MNEMONIC.split(' '));
