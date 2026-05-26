# Full Example Integration

A complete walkthrough based on the official example app from `vechain/react-native-vechain-wallet-link`.

## Project Dependencies

```json
{
  "dependencies": {
    "@vechain/react-native-wallet-link": "^1.0.9",
    "@vechain/sdk-core": "^2.0.5",
    "@vechain/sdk-network": "^2.0.5",
    "@react-native-async-storage/async-storage": "^2.2.0",
    "react-native-get-random-values": "^1.11.0",
    "events": "^3.3.0",
    "zustand": "^5.0.8"
  }
}
```

> **Expo projects** also need `expo-linking` to generate the correct redirect URL:
>
> ```bash
> npx expo install expo-linking
> ```
```

## Entry Point

Import the random values polyfill **first**:

```typescript
// index.js
import 'react-native-get-random-values';
import { registerRootComponent } from 'expo';
import App from './src/App';

registerRootComponent(App);
```

## State Management with Zustand

### Wallet session store

Persist keyPair, VeWorld public key, address, and session across app restarts:

```typescript
// stores/useVeWorldStore.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type { KeyPair } from '@vechain/react-native-wallet-link';

type VeWorldStore = {
  veWorldPublicKey: string | null;
  keyPair: KeyPair | null;
  address: string | null;
  session: string | null;
  setVeWorldPublicKey: (key: string | null) => void;
  setKeyPair: (keyPair: KeyPair | null) => void;
  setAddress: (address: string | null) => void;
  setSession: (session: string | null) => void;
  reset: () => void;
};

export const useVeWorldStore = create<VeWorldStore>()(
  persist(
    (set) => ({
      veWorldPublicKey: null,
      keyPair: null,
      address: null,
      session: null,
      setVeWorldPublicKey: (key) => set({ veWorldPublicKey: key }),
      setKeyPair: (keyPair) => set({ keyPair }),
      setAddress: (address) => set({ address }),
      setSession: (session) => set({ session }),
      reset: () =>
        set({
          veWorldPublicKey: null,
          keyPair: null,
          address: null,
          session: null,
        }),
    }),
    {
      name: 'veworld-store',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);
```

### Response store (for displaying results)

```typescript
// stores/useResponseStore.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

type ResponseStore = {
  response: string | null;
  setResponse: (response: string | null) => void;
  reset: () => void;
};

export const useResponseStore = create<ResponseStore>()(
  persist(
    (set) => ({
      response: '',
      setResponse: (response) => set({ response }),
      reset: () => set({ response: '' }),
    }),
    {
      name: 'response-store',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);
```

## App Root with VeWorldProvider

```tsx
// App.tsx
import React from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import {
  VeWorldProvider,
  decryptPayload,
  type OnVeWorldConnectedData,
  type OnVeWorldSignedTransactionData,
  type OnVeWorldSignedData,
} from '@vechain/react-native-wallet-link';
import { createURL } from 'expo-linking'; // Expo projects only
import { useVeWorldStore } from './stores/useVeWorldStore';
import { useResponseStore } from './stores/useResponseStore';
import { Home } from './screens/Home';

const TESTNET_URL = 'https://testnet.vechain.org';
const Stack = createNativeStackNavigator();

export default function App() {
  const {
    keyPair,
    setVeWorldPublicKey,
    setAddress,
    setSession,
    reset: resetVeWorld,
  } = useVeWorldStore();
  const { setResponse } = useResponseStore();

  // Expo: use createURL() to generate the correct redirect URL for your scheme.
  // This handles Expo Go (exp://), dev client, and production builds automatically.
  // For bare React Native, use a hardcoded scheme instead: "myapp://"
  const redirectUrl = createURL('/');

  return (
    <SafeAreaProvider>
      <VeWorldProvider
        appName="MyApp"
        appUrl="https://myapp.com"
        redirectUrl={redirectUrl}
        node={TESTNET_URL}
        config={{
          onVeWorldConnected: (response) => {
            if (!keyPair || !response?.response) return;
            if ('errorCode' in response.response) {
              setResponse(response.response.errorMessage);
              return;
            }
            const data = decryptPayload<OnVeWorldConnectedData>(
              keyPair.secretKey,
              response.response.publicKey,
              response.response.nonce,
              response.response.data
            );
            setVeWorldPublicKey(data.publicKey);
            setAddress(data.address);
            setSession(data.session);
          },

          onVeWorldDisconnected: (response) => {
            if (!response?.response) return;
            if ('errorCode' in response.response) {
              setResponse(response.response.errorMessage);
              return;
            }
            resetVeWorld();
          },

          onVeWorldSentTransaction: (response) => {
            if (!keyPair || !response?.response) return;
            if ('errorCode' in response.response) {
              setResponse(response.response.errorMessage);
              return;
            }
            const data = decryptPayload<OnVeWorldSignedTransactionData>(
              keyPair.secretKey,
              response.response.publicKey,
              response.response.nonce,
              response.response.data
            );
            setResponse(data.id);
          },

          onVeWorldSignedCertificate: (response) => {
            if (!keyPair || !response?.response) return;
            if ('errorCode' in response.response) {
              setResponse(response.response.errorMessage);
              return;
            }
            const data = decryptPayload<OnVeWorldSignedData>(
              keyPair.secretKey,
              response.response.publicKey,
              response.response.nonce,
              response.response.data
            );
            setResponse(data.signature);
          },

          onVeWorldSignedTypedData: (response) => {
            if (!keyPair || !response?.response) return;
            if ('errorCode' in response.response) {
              setResponse(response.response.errorMessage);
              return;
            }
            const data = decryptPayload<OnVeWorldSignedData>(
              keyPair.secretKey,
              response.response.publicKey,
              response.response.nonce,
              response.response.data
            );
            setResponse(data.signature);
          },
        }}
      >
        <NavigationContainer>
          <Stack.Navigator>
            <Stack.Screen name="Home" component={Home} />
          </Stack.Navigator>
        </NavigationContainer>
      </VeWorldProvider>
    </SafeAreaProvider>
  );
}
```

## Home Screen — Using the Hook

```tsx
// screens/Home.tsx
import React, { useEffect } from 'react';
import { View, Button, Text, StyleSheet, ScrollView } from 'react-native';
import { useVeWorldWallet } from '@vechain/react-native-wallet-link';
import { Address, Clause, VET, type TransactionClause } from '@vechain/sdk-core';
import { encodeBase64 } from 'tweetnacl-util';
import { useVeWorldStore } from '../stores/useVeWorldStore';
import { useResponseStore } from '../stores/useResponseStore';

export function Home() {
  const {
    generateKeyPair,
    connect,
    disconnect,
    signAndSendTransaction,
    signCertificate,
    signTypedData,
  } = useVeWorldWallet();

  const {
    keyPair,
    veWorldPublicKey,
    address,
    session,
    setKeyPair,
    reset: resetVeWorld,
  } = useVeWorldStore();

  const { response, reset: resetResponse } = useResponseStore();

  // Generate key pair on first mount
  useEffect(() => {
    if (!keyPair) {
      const kp = generateKeyPair();
      setKeyPair({
        secretKey: encodeBase64(kp.secretKey),
        publicKey: encodeBase64(kp.publicKey),
      });
    }
  }, [keyPair, generateKeyPair, setKeyPair]);

  const isConnected = !!address && !!session;

  const handleConnect = () => {
    if (!keyPair) return;
    resetResponse();
    connect(keyPair.publicKey);
  };

  const handleDisconnect = () => {
    if (!keyPair || !veWorldPublicKey || !session) return;
    resetResponse();
    disconnect(keyPair, veWorldPublicKey, session);
  };

  const handleSendVET = () => {
    if (!keyPair || !veWorldPublicKey || !session) return;
    resetResponse();

    const clauses: TransactionClause[] = [
      Clause.transferVET(
        Address.of('0x9199828f14cf883c8d311245bec34ec0b51fedcb'),
        VET.of(0.1)
      ) as TransactionClause,
    ];

    signAndSendTransaction(
      keyPair,
      veWorldPublicKey,
      session,
      clauses,
      'Send 0.1 VET'
    );
  };

  const handleSignCertificate = () => {
    if (!keyPair || !veWorldPublicKey || !session) return;
    resetResponse();

    signCertificate(keyPair, veWorldPublicKey, session, {
      purpose: 'identification',
      payload: { type: 'text', content: 'Hello, world!' },
    });
  };

  const handleSignTypedData = () => {
    if (!keyPair || !veWorldPublicKey || !session) return;
    resetResponse();

    signTypedData(keyPair, veWorldPublicKey, session, {
      domain: { name: 'My DApp', version: '1.0.0', chainId: 1 },
      origin: 'https://myapp.com',
      types: {
        Person: [
          { name: 'name', type: 'string' },
          { name: 'wallet', type: 'address' },
        ],
      },
      value: {
        name: 'John Doe',
        wallet: '0x9199828f14cf883c8d311245bec34ec0b51fedcb',
      },
    });
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.status}>
        {isConnected ? `Connected: ${address}` : 'Not connected'}
      </Text>

      {!isConnected ? (
        <Button title="Connect to VeWorld" onPress={handleConnect} />
      ) : (
        <>
          <Button title="Disconnect" onPress={handleDisconnect} />

          <Text style={styles.section}>Message Signing</Text>
          <Button title="Sign Certificate" onPress={handleSignCertificate} />
          <Button title="Sign Typed Data" onPress={handleSignTypedData} />

          <Text style={styles.section}>Transactions</Text>
          <Button title="Send 0.1 VET" onPress={handleSendVET} />
        </>
      )}

      {response ? (
        <Text style={styles.response}>Response: {response}</Text>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 20, gap: 12 },
  status: { fontSize: 16, fontWeight: 'bold', marginBottom: 8 },
  section: { fontSize: 14, fontWeight: '600', marginTop: 16 },
  response: { fontSize: 12, marginTop: 16, color: '#666' },
});
```

## Key Implementation Patterns

### 1. Always check errors before decrypting

Every callback must guard against error responses:

```typescript
if ('errorCode' in response.response) {
  // Handle error — do NOT attempt decryption
  return;
}
```

### 2. Persist session state

The keyPair, veWorldPublicKey, address, and session must survive app restarts. Use AsyncStorage with Zustand persist, MMKV, or any persistent store.

### 3. Generate key pair once

Generate a single key pair and reuse it for the lifetime of the session. Only generate a new one if the user explicitly resets.

### 4. Clean up on disconnect

When `onVeWorldDisconnected` fires, clear all stored wallet state (keyPair can optionally be preserved for reconnection).

### 5. Multi-clause transactions

Use `@vechain/sdk-core` `Clause` helpers to build transaction clauses:

```typescript
import { Clause, Address, VET, coder, type TransactionClause } from '@vechain/sdk-core';

// VET transfer
Clause.transferVET(Address.of(recipient), VET.of(amount))

// VTHO transfer (or any VIP-180 token)
const transferABI = coder.createInterface(['function transfer(address to, uint256 amount)']);
{
  to: VTHO_CONTRACT_ADDRESS,
  value: '0x0',
  data: transferABI.encodeFunctionData('transfer', [recipient, amount]),
}

// Multiple clauses in one transaction
signAndSendTransaction(keyPair, veWorldPublicKey, session, [clause1, clause2, clause3]);
```
