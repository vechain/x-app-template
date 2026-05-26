# @vechain/react-native-wallet-link — API Reference

## Installation

```bash
npm install @vechain/react-native-wallet-link
# Peer dependencies (required):
npm install @vechain/sdk-core @vechain/sdk-network react-native-get-random-values events
```

**Current version**: 1.0.9

**Runtime dependencies** (bundled): `tweetnacl`, `tweetnacl-util`

> **IMPORTANT**: Import `react-native-get-random-values` at the top of your entry file (before any NaCl usage) to polyfill `crypto.getRandomValues` in React Native.

## Exports

```typescript
// Components
export { VeWorldProvider } from './components/VeWorldProvider';

// Hooks
export { useVeWorldWallet } from './hooks/useVeWorldWallet';

// All types
export * from './types';

// Utilities
export {
  decryptPayload,
  encryptPayload,
  processResponse,
  isVeWorldResponse,
  LinkEvent,
} from './utils';
```

## VeWorldProvider

Wrap your app root with this provider. It sets up deep link listeners and dispatches wallet events.

```tsx
import { VeWorldProvider } from '@vechain/react-native-wallet-link';

<VeWorldProvider
  appName="MyApp"
  appUrl="https://myapp.com"
  redirectUrl="myapp://"
  node="https://testnet.vechain.org"
  config={{
    onVeWorldConnected: (response) => { /* handle connection */ },
    onVeWorldDisconnected: (response) => { /* handle disconnection */ },
    onVeWorldSentTransaction: (response) => { /* handle tx result */ },
    onVeWorldSignedCertificate: (response) => { /* handle certificate */ },
    onVeWorldSignedTypedData: (response) => { /* handle typed data */ },
  }}
>
  {children}
</VeWorldProvider>
```

### Props

| Prop | Type | Description |
|------|------|-------------|
| `appName` | `string` | Application display name shown in VeWorld |
| `appUrl` | `string` | Application URL identifier |
| `redirectUrl` | `string` | Deep link redirect URI (e.g., `myapp://`) |
| `node` | `string` | VeChain node endpoint URL |
| `config` | `VeWorldConfig` | Event handler callbacks (see below) |

### VeWorldConfig callbacks

Each callback receives `OnVeWorldResponseWithEvent`:

```typescript
type OnVeWorldResponseWithEvent = {
  event: LinkEvent;
  response: OnVeWorldResponse | OnVeWorldError | undefined;
};

type OnVeWorldResponse = {
  data: string;    // encrypted payload
  nonce: string;   // decryption nonce
  publicKey: string;
};

type OnVeWorldError = {
  errorCode: string;
  errorMessage: string;
};
```

**Always check for errors before decrypting**:

```typescript
onVeWorldConnected: (response) => {
  if (!response?.response) return;

  // Check for error
  if ('errorCode' in response.response) {
    console.error(response.response.errorMessage);
    return;
  }

  // Decrypt successful response
  const data = decryptPayload<OnVeWorldConnectedData>(
    keyPair.secretKey,
    response.response.publicKey,
    response.response.nonce,
    response.response.data
  );

  // data = { publicKey, address, session }
}
```

### Context value

The provider exposes via `VeWorldContext`:

- `appName`, `appUrl`, `redirectUrl` — from props
- `thor` — `ThorClient` instance connected to the configured node

## useVeWorldWallet Hook

Access all wallet operations. Must be used within `VeWorldProvider`.

```typescript
import { useVeWorldWallet } from '@vechain/react-native-wallet-link';

const {
  generateKeyPair,
  connect,
  disconnect,
  signAndSendTransaction,
  signCertificate,
  signTypedData,
} = useVeWorldWallet();
```

### generateKeyPair

Creates a NaCl box key pair for encrypted communication with VeWorld.

```typescript
const generateKeyPair: () => nacl.BoxKeyPair;
// Returns { secretKey: Uint8Array, publicKey: Uint8Array }
```

**Encode for storage**:

```typescript
import { encodeBase64 } from 'tweetnacl-util';

const kp = generateKeyPair();
const keyPair = {
  secretKey: encodeBase64(kp.secretKey),
  publicKey: encodeBase64(kp.publicKey),
};
// Store keyPair persistently (AsyncStorage, MMKV, etc.)
```

### connect

Initiates wallet connection by opening VeWorld via deep link.

```typescript
const connect: (publicKey: string) => Promise<void>;
```

- `publicKey` — Base64-encoded public key from `generateKeyPair`
- Automatically fetches genesis block ID from the configured node
- Opens VeWorld with connection parameters
- Response arrives in `onVeWorldConnected` callback

**Response data** (after decryption):

```typescript
type OnVeWorldConnectedData = {
  publicKey: string;  // VeWorld's public key for future encryption
  address: string;    // Connected wallet address
  session: string;    // Session token for authenticated requests
};
```

### disconnect

Ends the wallet session.

```typescript
const disconnect: (
  keyPair: KeyPair,
  veWorldPublicKey: string,
  session: string,
  description?: string
) => Promise<void>;
```

### signAndSendTransaction

Signs and broadcasts a transaction via VeWorld. Supports multi-clause transactions.

```typescript
const signAndSendTransaction: (
  keyPair: KeyPair,
  veWorldPublicKey: string,
  session: string,
  transaction: TransactionClause[],
  description?: string
) => Promise<null>;
```

**Response data** (after decryption in `onVeWorldSentTransaction`):

```typescript
type OnVeWorldSignedTransactionData = {
  id: string;                // Transaction ID
  transaction: Transaction;  // Full transaction object
};
```

**Example — send VET**:

```typescript
import { Address, Clause, VET, type TransactionClause } from '@vechain/sdk-core';

const clauses: TransactionClause[] = [
  Clause.transferVET(
    Address.of('0x9199828f14cf883c8d311245bec34ec0b51fedcb'),
    VET.of(0.1)
  ) as TransactionClause,
];

await signAndSendTransaction(keyPair, veWorldPublicKey, session, clauses, 'Send 0.1 VET');
```

### signCertificate

Signs a certificate message (identification, verification, or attestation).

```typescript
const signCertificate: (
  keyPair: KeyPair,
  veWorldPublicKey: string,
  session: string,
  certificate: CertificateMessage,
  description?: string
) => Promise<void>;
```

**CertificateMessage type**:

```typescript
type CertificateMessage = {
  purpose: 'identification' | 'verification' | 'attestation';
  payload: {
    type: string;
    content: string;
  };
  domain?: string;
  timestamp?: number;
};
```

**Response data** (after decryption in `onVeWorldSignedCertificate`):

```typescript
type OnVeWorldSignedData = {
  signature: string;
  annex?: {
    domain: string;
    timestamp: number;
    signer: string;
  };
};
```

### signTypedData

Signs EIP-712 typed data.

```typescript
const signTypedData: (
  keyPair: KeyPair,
  veWorldPublicKey: string,
  session: string,
  typedData: TypedDataBody,
  description?: string
) => Promise<void>;
```

**TypedDataBody type**:

```typescript
type TypedDataBody = {
  domain: ethers.TypedDataDomain;
  origin: string;
  types: Record<string, ethers.TypedDataField[]>;
  value: Record<string, unknown>;
};
```

## KeyPair Type

All signing methods require a `KeyPair` with Base64-encoded keys:

```typescript
type KeyPair = {
  secretKey: string;  // Base64-encoded NaCl secret key
  publicKey: string;  // Base64-encoded NaCl public key
};
```

## Utility Functions

### decryptPayload

Decrypt an encrypted response from VeWorld.

```typescript
function decryptPayload<T>(
  secretKey: string,        // Base64 secret key
  veWorldPublicKey: string, // Base64 VeWorld public key (from response)
  nonce: string,            // Base64 nonce (from response)
  payload: string           // Base64 encrypted data (from response)
): T;
```

### encryptPayload

Encrypt a payload to send to VeWorld (used internally by the hook).

```typescript
function encryptPayload(
  secretKey: string,
  veWorldPublicKey: string,
  payload: string
): [string, string]; // [nonce, encryptedPayload] both Base64
```

### isVeWorldResponse

Check if a deep link path is a VeWorld callback event.

```typescript
function isVeWorldResponse(path: string): boolean;
```

### processResponse

Parse a deep link URL into a structured response.

```typescript
function processResponse(url: string): Promise<OnVeWorldResponseWithEvent>;
```

### LinkEvent Enum

```typescript
enum LinkEvent {
  Connect = 'connect',
  Disconnect = 'disconnect',
  SignTransaction = 'sign-transaction',
  SignCertificate = 'sign-certificate',
  SignTypedData = 'sign-typed-data',
}
```

## Network Configuration

Pass the appropriate node URL to `VeWorldProvider`:

| Network | Node URL |
|---------|----------|
| Mainnet | `https://mainnet.vechain.org` |
| Testnet | `https://testnet.vechain.org` |
| Solo | `http://localhost:8669` (or custom) |

## Additional Types

```typescript
type VeWorldNetwork = 'mainnet' | 'testnet' | 'solo';

type TransactionMethod =
  | 'thor_sendTransaction'
  | 'thor_signCertificate'
  | 'thor_signTypedData';

type TransactionMessage = TransactionClause & {
  comment?: string;
  abi?: object;
};

type ErrorResponse = {
  error_code: string;
  error_message: string;
};
```
