# VeChain Kit — Hooks

## When to use

Use when the user asks about: useWallet, useCallClause, useSendTransaction, useBuildTransaction, useSignMessage, useSignTypedData, contract reads, transactions, VET domains, NFTs, blockchain hooks, language/currency hooks, or @vechain/contract-getters.

---

## General

All hooks use TanStack Query (React Query) and return a consistent shape:
```typescript
{ data, isLoading, isError, error, refetch, isRefetching }
```

All Kit queries use the `VECHAIN_KIT` prefix — use it for broad invalidation:
```tsx
queryClient.invalidateQueries({ queryKey: ['VECHAIN_KIT'] }); // all Kit queries
queryClient.invalidateQueries({ queryKey: ['VECHAIN_KIT', 'CURRENT_BLOCK'] }); // specific
```

See the **frontend** skill for React Query caching, invalidation, and loading state patterns.

## useWallet -- Connection State

```tsx
import { useWallet } from '@vechain/vechain-kit';

function MyComponent() {
  const {
    account,          // Active account { address, domain, image } — smart account for Privy, wallet for DappKit
    connectedWallet,  // Current wallet regardless of method (Privy embedded or self-custody)
    smartAccount,     // { address, domain, image, isDeployed, isActive, version }
    privyUser,        // Privy User object if connected via Privy, null otherwise
    connection,       // Connection state and metadata
    disconnect,       // Disconnects + dispatches 'wallet_disconnected' event
  } = useWallet();

  // connection properties:
  // isConnected, isLoading,
  // isConnectedWithSocialLogin, isConnectedWithDappKit,
  // isConnectedWithCrossApp, isConnectedWithPrivy, isConnectedWithVeChain,
  // isInAppBrowser (true when running in VeWorld mobile browser),
  // source: { type: 'privy' | 'wallet' | 'privy-cross-app', displayName },
  // nodeUrl, delegatorUrl, chainId, network

  if (!connection.isConnected) return <div>Not connected</div>;
  return <div>Connected: {account?.address}</div>;
}
```

**SmartAccount**: `isDeployed` indicates whether the smart account contract is deployed on-chain (deployed lazily on first transaction to save gas). `version` is the contract version (V3 required for multi-clause + replay protection).

## useCallClause -- Contract Reads (preferred pattern)

Use `useCallClause` for all contract read operations. It wraps React Query for caching, refetching, and loading states. Prefer typed contract factories from `@vechain/vechain-contract-types` or your own TypeChain output.

```tsx
import { useCallClause, getCallClauseQueryKey } from '@vechain/vechain-kit';
import { MyContract__factory } from '../typechain-types';

// Basic usage with typed factory ABI
export const useTokenBalance = (address: string) => {
  return useCallClause({
    abi: MyContract__factory.abi,
    address: CONTRACT_ADDRESS,
    method: 'balanceOf',
    args: [address],
    queryOptions: { enabled: !!address },
  });
};

// In a component
function Balance({ address }: { address: string }) {
  const { data, isLoading } = useTokenBalance(address);
  if (isLoading) return <Skeleton height="20px" width="100px" />;
  return <div>Balance: {data?.toString()}</div>;
}
```

**Data transformation** with `select` (preferred over `useMemo` in components):
```tsx
return useCallClause({
  abi: VOT3__factory.abi,
  address: contractAddress,
  method: 'convertedB3trOf' as const,
  args: [address ?? ''],
  queryOptions: {
    enabled: !!address,
    select: (data) => ({
      balance: ethers.formatEther(data[0]),
      formatted: humanNumber(ethers.formatEther(data[0])),
    }),
  },
});
```

**Query keys** for cache invalidation:
```tsx
import {
  getCallClauseQueryKey,
  getCallClauseQueryKeyWithArgs,
} from '@vechain/vechain-kit';

// Without args (for methods with no params)
const key = getCallClauseQueryKey({
  abi, address: contractAddress, method: 'currentRoundId' as const,
});

// With args (for methods with params)
const key = getCallClauseQueryKeyWithArgs({
  abi, address: contractAddress, method: 'balanceOf' as const, args: [address],
});

queryClient.invalidateQueries({ queryKey: key });
```

**Organize contract hooks** in a dedicated directory (e.g., `src/api/contracts/`):
```
src/api/contracts/
├── useTokenBalance.ts
├── useTokenAllowance.ts
├── useVaultDeposit.ts
└── index.ts
```

## Batch Contract Reads

Use `executeMultipleClausesCall` for multiple reads in one call:

```tsx
import { executeMultipleClausesCall } from '@vechain/vechain-kit';

const thor = useThor();
const results = await executeMultipleClausesCall({
  thor,
  calls: addresses.map((addr) => ({
    abi: ERC20__factory.abi,
    functionName: 'balanceOf',
    address: addr as `0x${string}`,
    args: [userAddress],
  })),
});
```

## useBuildTransaction -- Clause Builder Pattern

Wraps `useSendTransaction` with a clause-builder function. Use `thor.contracts.load().clause` to build clauses from loaded contracts:

```tsx
import { useBuildTransaction, useWallet } from '@vechain/vechain-kit';

const useApproveAndSwap = () => {
  const { account } = useWallet();
  const thor = useThor();

  return useBuildTransaction({
    clauseBuilder: (tokenAddress: string, amount: string) => {
      if (!account?.address) return [];
      return [
        {
          ...thor.contracts.load(tokenAddress, ERC20__factory.abi)
            .clause.approve(swapAddress, ethers.parseEther(amount)).clause,
          comment: 'Approve token spending',
        },
        {
          ...thor.contracts.load(swapAddress, SwapContract__factory.abi)
            .clause.swap(tokenAddress, ethers.parseEther(amount)).clause,
          comment: 'Execute swap',
        },
      ];
    },
    onTxConfirmed: () => {
      queryClient.invalidateQueries({ queryKey: ['TOKEN_BALANCE'] });
    },
  });
};
```

## useSendTransaction -- Core Transaction Hook

**Use this for all transactions.** Handles both wallet and social login users automatically.

```tsx
import { useSendTransaction, useWallet } from '@vechain/vechain-kit';
import { useQueryClient } from '@tanstack/react-query';

function TransactionComponent() {
  const { account } = useWallet();
  const queryClient = useQueryClient();

  const {
    sendTransaction,
    status,              // 'ready' | 'pending' | 'waitingConfirmation' | 'success' | 'error'
    txReceipt,
    resetStatus,
    isTransactionPending,
    error,               // { type: 'UserRejectedError' | 'RevertReasonError', reason }
  } = useSendTransaction({
    signerAccountAddress: account?.address ?? '',
    // Gas options (pick one):
    // gasPadding: 0.2,       // Float 0–1: adds % buffer on top of estimated gas
    // suggestedMaxGas: 40000000, // Integer: explicit gas cap, overrides estimation + padding
    onTxConfirmed: () => {
      // CRITICAL: Invalidate ALL queries affected by this transaction.
      // Think through every component that reads data changed by the tx
      // (balances, registration status, navbar items, banners, lists).
      // See frontend.md "Cache Invalidation After Transactions" for details.
      queryClient.invalidateQueries({
        queryKey: getCallClauseQueryKey(CONTRACT, 'balanceOf', [account?.address]),
      });
    },
  });

  const handleSend = async () => {
    await sendTransaction([
      {
        to: '0xContractAddress',
        value: '0x0',
        data: '0xencodedFunctionData',
        comment: 'User-facing description of this operation',
        abi: functionABI,   // Optional: for UI display
      },
    ]);
  };

  return (
    <button onClick={handleSend} disabled={isTransactionPending}>
      {status === 'pending' ? 'Sending...' : 'Send Transaction'}
    </button>
  );
}
```

**Critical**: `useSendTransaction` is **mandatory** when social login is enabled. For apps without social login, you can alternatively use the `signer` exported by the kit and follow the SDK transaction guides directly.

**Critical**: Pre-fetch all data before calling `sendTransaction`. Fetching during submission can trigger browser pop-up blockers for social login users.

**Retry pattern**: Use `resetStatus` + `onTryAgain` for retry UX:
```tsx
const handleTryAgain = useCallback(async () => {
  resetStatus();
  await sendTransaction(clauses);
}, [sendTransaction, clauses, resetStatus]);

<TransactionModal onTryAgain={handleTryAgain} isClosable /* ...other props */ />
```

**Per-transaction delegation**: Override fee delegation for specific transactions:
```tsx
// App sponsors this transaction
await sendTransaction(clauses, 'https://your-delegator.com/delegate');

// User pays via Generic Delegator (default)
await sendTransaction(clauses);
```

## useTransferVET / useTransferERC20 -- Convenience Hooks

```tsx
import { useTransferVET, useTransferERC20, useWallet } from '@vechain/vechain-kit';

// VET transfer
const { sendTransaction } = useTransferVET({
  senderAddress: account?.address ?? '',
  receiverAddress: '0xRecipient',
  amount: '1000000000000000000', // 1 VET in wei
});

// ERC-20 transfer
const { sendTransaction } = useTransferERC20({
  senderAddress: account?.address ?? '',
  receiverAddress: '0xRecipient',
  amount: '1000000000000000000',
  tokenAddress: '0xTokenContract',
  tokenName: 'B3TR',
});
```

## Multi-Clause Transactions

```tsx
const handleBatchOperation = async () => {
  await sendTransaction([
    { to: tokenAddr, value: '0x0', data: approveData, comment: 'Approve spending' },
    { to: vaultAddr, value: '0x0', data: depositData, comment: 'Deposit tokens' },
  ]);
};
```

## Login Hooks

```tsx
import {
  useLoginWithPasskey,
  useLoginWithOAuth,
  useLoginWithVeChain,
} from '@vechain/vechain-kit';

const { loginWithPasskey } = useLoginWithPasskey();
const { initOAuth } = useLoginWithOAuth();
const { login: loginWithVeChain } = useLoginWithVeChain();

// OAuth providers: 'google' | 'twitter' | 'apple' | 'discord' | 'github' | 'linkedin'
```

## Blockchain Hooks

```tsx
import { useCurrentBlock, useTxReceipt, useEvents } from '@vechain/vechain-kit';

const { data: block } = useCurrentBlock();             // Auto-refreshes every 10s
const { data: receipt } = useTxReceipt(txId, 5);       // Poll for receipt (blockTimeout default: 5)
const { data: events } = useEvents({                   // Contract events
  abi: contractABI,
  address: '0xContract',
  eventName: 'Transfer',
  filterParams: { from: '0x...' },
});
```

## Network & Config Hooks

```tsx
import { useGetChainId, useGetNodeUrl, useAppConfig } from '@vechain/vechain-kit';

const { data: chainId } = useGetChainId();   // Chain ID from genesis block
const nodeUrl = useGetNodeUrl();              // Current node URL (custom or default)
```

### useAppConfig -- Merged Network Config

Returns the full `AppConfig` for the current network, with any `contractAddresses` overrides from the provider applied. Prefer this over `getConfig()` inside React components.

```tsx
import { useAppConfig } from '@vechain/vechain-kit';

function MyComponent() {
  const config = useAppConfig();
  // config.b3trContractAddress — uses provider override if set, otherwise network default
  // config.vot3ContractAddress
  // config.nodeUrl, config.explorerUrl, etc.
}
```

## Legal Documents Hook

After configuring `legalDocuments` on the provider, read agreement status with:

```tsx
import { useLegalDocuments } from '@vechain/vechain-kit';

const {
  documents,                    // All configured legal documents
  agreements,                   // User's agreement records
  documentsNotAgreed,           // Documents the user hasn't agreed to yet
  hasAgreedToRequiredDocuments, // Boolean — true when all required docs are accepted
} = useLegalDocuments();
```

## Oracle, Token, and Domain Hooks

```tsx
import {
  useGetTokenUsdPrice,
  useGetCustomTokenInfo,
  useGetCustomTokenBalances,
  useVechainDomain,
  useGetAvatar,
} from '@vechain/vechain-kit';

const { data: vetPrice } = useGetTokenUsdPrice('VET');   // Supported: 'VET', 'VTHO', 'B3TR' (on-chain oracle)
const { data: tokenInfo } = useGetCustomTokenInfo('0xToken');
const { data: balances } = useGetCustomTokenBalances(address, ['0xToken1', '0xToken2']);
const { data: domain } = useVechainDomain('0xAddress');   // address -> domain
const { data: resolved } = useVechainDomain('name.vet');  // domain -> address
const { data: avatar } = useGetAvatar('name.vet');
```

### VET Domain Hooks (full list)

**Resolution:**

- `useVechainDomain(addressOrDomain)` — returns `{ address?, domain?, isValidAddressOrDomain }`
- `useIsDomainProtected(domain)` — returns `boolean` (whether the domain is protected from claiming)
- `useGetDomainsOfAddress(address, parentDomain?)` — returns `{ domains: Array<{ name }> }`

**Records:**

- `useGetTextRecords(domain)` — returns all text records for a domain
- `useGetAvatar(domain)` — returns the avatar image URL directly (converts URI to URL), or `null`
- `useGetAvatarOfAddress(address)` — resolves the primary domain, then returns its avatar URL; falls back to a Picasso image if no domain or avatar is set
- `useGetResolverAddress(domain)` — returns the resolver contract address

**Mutations:**

- `useUpdateTextRecord({ resolverAddress, onSuccess?, onError?, signerAccountAddress? })` — returns `{ sendTransaction, isTransactionPending, error }`
- `useClaimVeWorldSubdomain({ subdomain, domain, onSuccess?, onError?, alreadyOwned? })` — returns `{ sendTransaction, isTransactionPending, error }` (specific to `veworld.vet` subdomains)

### VET Domain Text Records

`.vet` domains support ENS-compatible text records — key-value pairs stored on the resolver (ENSIP-5/18). Common records: `display` (preferred capitalisation), `avatar`, `description`, `header` (banner image, 1:3 ratio), `email`, `url`, `location`, `phone`, `keywords`. Apps can also store custom records with a prefix (e.g. `com.discord`, `org.reddit`). Records are read from the name's resolver; write availability depends on the resolver implementation.

## NFT and IPFS Hooks

```tsx
import { useNFTImage, useNFTMetadataUri, useIpfsImage } from '@vechain/vechain-kit';

// Full flow: address → tokenId → metadata → image (all resolved automatically)
const { imageData, imageMetadata, tokenID, isLoading } = useNFTImage({
  address: walletAddress,
  contractAddress: nftContractAddress,
});

// Just the metadata URI for a known token ID
const { data: metadataUri } = useNFTMetadataUri({ tokenId, contractAddress });

// Resolve any IPFS URI to a gateway URL
const { data: imageUrl } = useIpfsImage(ipfsUri);
```

## Sign Messages

```tsx
import { useSignMessage, useSignTypedData } from '@vechain/vechain-kit';

// Sign a plain message
const { signMessage, isSigningPending, signature } = useSignMessage();
const sig = await signMessage('Hello VeChain');

// Sign EIP-712 typed data
const {
  signTypedData,
  isSigningPending: isTypedPending,
  signature: typedSig,
} = useSignTypedData();

const result = await signTypedData({
  domain: { name: 'MyApp', version: '1', chainId: 100009 },
  types: { Message: [{ name: 'content', type: 'string' }] },
  message: { content: 'Verify wallet ownership' },
  primaryType: 'Message',
}, { signer: account?.address }); // signer option required for proper routing
```

## Certificate Signing (Wallet Authentication)

To verify wallet ownership for backend JWT flows, use `signTypedData` with EIP-712. **Do not use `useConnex` / `connex.vendor.sign('cert', ...)`** — that is deprecated.

**Smart account warning:** Social login users own a smart account (contract). They sign with their Privy embedded wallet, not the smart account directly. Your backend **must verify that the signer address is the owner of the smart account**, not just compare it to the connected address.

**Frontend hook pattern:**

```tsx
const { signTypedData } = useSignTypedData();
const { account } = useWallet();

const domain = { name: 'MyApp', version: '1' };
const types = {
  Authentication: [
    { name: 'user', type: 'address' },
    { name: 'timestamp', type: 'string' },
  ],
};

const message = { user: account?.address, timestamp: new Date().toISOString() };
const signature = await signTypedData(
  { domain, types, message, primaryType: 'Authentication' },
  { signer: account?.address },
);
// Send { signature, message } to your backend
```

**Backend verification:**

```typescript
import { ethers } from 'ethers';

const signerAddress = ethers.verifyTypedData(domain, types, message, signature);
// For wallet users: signerAddress === account address
// For social login users: signerAddress is the embedded wallet —
//   verify it is the owner of the smart account on-chain
```

## Language and Currency Hooks

Bidirectional sync between VeChain Kit settings and your app. Changes in either direction are reflected in both places. Values persist in localStorage (`i18nextLng` for language, `vechain_kit_currency` for currency).

**Provider props:**

```tsx
<VeChainKitProvider
  language="en"                        // Initial language code
  defaultCurrency="usd"               // 'usd' | 'eur' | 'gbp'
  onLanguageChange={(lang) => {}}      // Fired when user changes language in Kit settings
  onCurrencyChange={(currency) => {}}  // Fired when user changes currency in Kit settings
>
```

**Hooks:**

```tsx
import {
  useCurrentLanguage,
  useCurrentCurrency,
  useVeChainKitConfig,
} from '@vechain/vechain-kit';

// Language
const { currentLanguage, setLanguage } = useCurrentLanguage();
setLanguage('fr');

// Currency
const { currentCurrency, setCurrency } = useCurrentCurrency();
setCurrency('eur'); // 'usd' | 'eur' | 'gbp'

// Full config (includes both + other config properties)
const config = useVeChainKitConfig();
config.currentLanguage; // current runtime value
config.currentCurrency; // current runtime value
config.setLanguage('de');
config.setCurrency('gbp');
```

## @vechain/contract-getters (Framework-Agnostic Reads)

For read-only blockchain queries outside of React components, use `@vechain/contract-getters`. It provides typed getters for VeBetterDAO data (B3TR, VOT3 balances, allocation voting, VeBetter Passport), VET domains, ERC-20 tokens, and more. Works in both Node.js and browser environments.

```bash
npm install @vechain/contract-getters
# Peer dependencies
npm install @vechain/vechain-contract-types @vechain/sdk-network ethers
```

**Simplest usage (no client setup needed — defaults to mainnet):**

```typescript
import { getVot3Balance, getB3trBalance } from '@vechain/contract-getters';

const vot3Balance = await getVot3Balance('0xUserAddress');
const b3trBalance = await getB3trBalance('0xUserAddress');
```

**With custom network:**

```typescript
import { getVot3Balance } from '@vechain/contract-getters';

const balance = await getVot3Balance('0xUserAddress', {
  networkUrl: 'https://testnet.vechain.org',
});
```

**With existing ThorClient (for projects already using VeChain SDK):**

```typescript
import { ThorClient } from '@vechain/sdk-network';
import { VeChainClient, getVot3Balance } from '@vechain/contract-getters';

const thorClient = ThorClient.at('https://testnet.vechain.org');
const vechainClient = VeChainClient.from(thorClient);

const balance = await getVot3Balance('0xUserAddress', { client: vechainClient });
```

**Available modules:** `b3tr`, `vot3`, `erc20`, `vetDomain`, `allocationVoting`, `allocationPool`, `veBetterPassport`, `relayerRewardsPool`.

Use this package when you need blockchain reads in:

- Backend scripts or API routes
- Non-React frontend frameworks
- Utility functions outside of component lifecycle

For React components, prefer the VeChain Kit hooks (`useCallClause`, `useVechainDomain`, etc.) instead, as they integrate with React Query for caching and reactivity.
