# dapp-kit (Lightweight Alternative)

## When to use

Use when the user asks about: dapp-kit, DAppKitProvider, lightweight wallet connection, non-React VeChain frontend.

See the **frontend** skill for choosing VeChain Kit vs dapp-kit and shared frontend patterns.

## When to Choose dapp-kit Over VeChain Kit

- Bundle size is critical
- Non-React framework (Vue, Svelte, Angular)
- Wallet connection only (no social login, no pre-built transaction UI)
- Minimal dependency footprint

---

## Setup

```bash
npm install @vechain/dapp-kit-react
```

```tsx
import { DAppKitProvider } from '@vechain/dapp-kit-react';

<DAppKitProvider
  nodeUrl="https://testnet.vechain.org/"
  genesis="test"
  usePersistence={true}
  allowedWallets={['veworld', 'wallet-connect']}
>
  <YourApp />
</DAppKitProvider>
```

---

## Available Hooks

| Hook | Description |
|------|-------------|
| `useWallet()` | Connection state, account address, disconnect |
| `useThor()` | Thor client for direct blockchain access |
| `useWalletModal()` | Open/close wallet connection modal |
| `useVechainDomain()` | Resolve .vet domain names |
| `useSendTransaction()` | Send transactions with optional fee delegation |

### useThor

```tsx
import { useThor } from '@vechain/dapp-kit-react';

const thor = useThor();
// Use thor for contract reads, block queries, etc.
```

### useSendTransaction

```tsx
import { useSendTransaction } from '@vechain/dapp-kit-react';

function SendButton() {
  const { sendTransaction } = useSendTransaction();

  const handleSend = async () => {
    const result = await sendTransaction({
      clauses: [
        { to: '0x...', value: '0x0', data: encodedCallData },
      ],
      comment: 'Description for the user',
      // Optional: app-sponsored fee delegation
      delegatorUrl: 'https://sponsor-testnet.vechain.energy/by/YOUR_PROJECT_ID',
    });

    console.log('Transaction ID:', result.id);
  };

  return <button onClick={handleSend}>Send</button>;
}
```

### Components

```tsx
import { WalletButton } from '@vechain/dapp-kit-react';

<WalletButton />
```

---

## Limitations vs VeChain Kit

- No social login (Privy) -- DIY only, see the **vechain-kit** skill (`references/kit-social-login.md`)
- No pre-built transaction UI (TransactionModal, TransactionToast)
- No contract read hooks (useCallClause) -- build your own with React Query + `useThor()`
- No token management hooks
- No smart account support
- No i18n

For contract reads without VeChain Kit's `useCallClause`, build custom React Query hooks:

```tsx
import { useQuery } from '@tanstack/react-query';
import { useThor } from '@vechain/dapp-kit-react';

export function useTokenBalance(contractAddress: string, userAddress: string) {
  const thor = useThor();

  return useQuery({
    queryKey: ['contract', contractAddress, 'balanceOf', userAddress],
    queryFn: async () => {
      const contract = thor.contracts.load(contractAddress, ERC20_ABI);
      return contract.read.balanceOf(userAddress);
    },
    enabled: !!userAddress && !!thor,
    staleTime: 10_000,
  });
}
```
