# Frontend Development Patterns

## When to use

Use when the user asks about: frontend, React, Next.js, React Query, caching, query keys, loading states, skeletons, Turborepo, Chakra UI, i18n, state management, dapp-kit vs VeChain Kit.

## Choosing VeChain Kit vs dapp-kit

| Criteria | VeChain Kit | dapp-kit |
|----------|-------------|----------|
| **Best for** | Full-featured dApps | Lightweight wallet-only |
| **Frameworks** | React, Next.js only | React, Next, Vue, Svelte, Angular |
| **Social login** | Yes (Privy, built-in) | DIY only (complex, see the **vechain-kit** skill) |
| **Pre-built UI** | WalletButton, modals, transaction UI | Minimal (WalletButton only) |
| **Transaction hooks** | useSendTransaction, useTransferVET, useTransferERC20 | useSendTransaction (basic) |
| **Contract read hooks** | useCallClause (React Query-based) | None (use SDK directly) |
| **Token management** | Built-in (balances, swaps, transfers) | Manual |
| **Smart accounts** | Yes (account abstraction) | No |
| **VET domains** | Built-in hooks | Basic |
| **Bundle size** | Larger | Smaller |
| **i18n** | Built-in | No |

**Rule of thumb**: Use VeChain Kit unless bundle size is critical or you need non-React framework support.
See [Should I Use It?](https://docs.vechainkit.vechain.org/discover-vechain-kit/should-i-use-it) for details.

### Quick Start (Template)
```bash
npx create-vechain-dapp@latest
```

Available templates:
| Template | Description |
|----------|-------------|
| **X2Earn** | Monorepo (Turbo) with React frontend, Express.js backend, Hardhat contracts, ChatGPT image recognition, VeBetterDAO integrations |
| **Simple Dapp** | Monorepo (Turbo) with React + Hardhat. Available in VeChain Kit or DAppKit variants |
| **Buy Me Coffee** | Guided tutorial: build a complete dApp with smart contract integration |
| **Smart Contract** | Hardhat-only template for contract development without frontend |

---

## React Query (TanStack Query) Patterns

React Query (`@tanstack/react-query`) is the data-fetching backbone for VeChain frontend projects. VeChain Kit hooks (e.g., `useCallClause`) are built on React Query. Follow these patterns for all data fetching.

### Query Key Structure

Use consistent, hierarchical query keys for caching and invalidation:

```tsx
// Pattern: [scope, entity, ...params]
const queryKey = ['contract', contractAddress, 'balanceOf', address];
const queryKey = ['indexer', 'transactions', { address, page }];
const queryKey = ['token', 'price', 'VET'];
```

VeChain Kit provides `getCallClauseQueryKey` for contract reads:
```tsx
import { getCallClauseQueryKey } from '@vechain/vechain-kit';

const key = getCallClauseQueryKey(CONTRACT_ADDRESS, 'balanceOf', [address]);
```

### Cache Invalidation After Transactions (CRITICAL)

**Every `onTxConfirmed` callback MUST invalidate all queries whose data could have changed.** This is a hard rule, not a suggestion. Stale UI after a successful transaction is a bug -- users see outdated balances, missing navigation items, or phantom banners because queries still hold pre-transaction data.

**Before writing any `useSendTransaction`, ask yourself:**
1. What on-chain state does this transaction change? (e.g., registration status, balances, reward claims)
2. Which queries read that state? (e.g., `useRelayerRegistration`, `useCallClause` for `balanceOf`, custom `useQuery` hooks)
3. Are there UI elements gated on that data? (e.g., navbar items, banners, badges, conditional buttons)

**Invalidate ALL of them in `onTxConfirmed`.**

```tsx
import { useQueryClient } from '@tanstack/react-query';
import { useSendTransaction, useWallet, getCallClauseQueryKey } from '@vechain/vechain-kit';

function StakeButton({ amount }: { amount: string }) {
  const queryClient = useQueryClient();
  const { account } = useWallet();

  const { sendTransaction, status } = useSendTransaction({
    signerAccountAddress: account?.address ?? '',
    onTxConfirmed: () => {
      // Invalidate all queries that might be affected
      queryClient.invalidateQueries({
        queryKey: getCallClauseQueryKey(STAKING_CONTRACT, 'stakedBalance', [account?.address]),
      });
      queryClient.invalidateQueries({
        queryKey: getCallClauseQueryKey(TOKEN_CONTRACT, 'balanceOf', [account?.address]),
      });
    },
  });

  // ...
}
```

**Broad invalidation** when many queries could be affected:
```tsx
// Invalidate all queries for a contract
queryClient.invalidateQueries({ queryKey: ['contract', contractAddress] });

// Invalidate everything -- prefer this when the transaction affects
// multiple components across the app (e.g., registration, role changes)
queryClient.invalidateQueries();
```

**Common mistakes:**
- Forgetting to invalidate navbar/sidebar queries after a state change (e.g., registering as a relayer should update the "Manage Relayer" nav link)
- Only invalidating the "primary" query but missing secondary effects (e.g., claiming rewards should also refresh the unclaimed rewards banner, round data, and balance displays)
- Relying on stale static data (e.g., a `report.json`) instead of verifying on-chain state after a write -- always prefer on-chain reads (`useCallClause` / `simulateTransaction`) over cached static files for data that can change via transactions

### Batch Queries with useQueries

When fetching multiple independent values, use `useQueries` to parallelize:

```tsx
import { useQueries } from '@tanstack/react-query';

function PortfolioBalances({ tokens }: { tokens: string[] }) {
  const balanceQueries = useQueries({
    queries: tokens.map((tokenAddress) => ({
      queryKey: ['contract', tokenAddress, 'balanceOf', userAddress],
      queryFn: () => fetchTokenBalance(tokenAddress, userAddress),
      staleTime: 30_000,
    })),
  });

  const isLoading = balanceQueries.some((q) => q.isLoading);
  const balances = balanceQueries.map((q) => q.data);

  if (isLoading) return <BalancesSkeleton />;
  // ...
}
```

### Loading States and Skeletons

Always use `isLoading` to show skeletons. Never render empty/zero states while data is loading:

```tsx
function TokenBalance({ address }: { address: string }) {
  const { data, isLoading } = useCallClause({
    abi: Token__factory.abi,
    address: TOKEN_ADDRESS,
    method: 'balanceOf',
    args: [address],
    queryOptions: { enabled: !!address },
  });

  // GOOD: skeleton while loading
  if (isLoading) return <Skeleton height="20px" width="100px" />;

  // GOOD: render data
  return <Text>{formatBalance(data)}</Text>;
}
```

**Distinguish loading states:**
- `isLoading` -- first load, no cached data yet → show skeleton
- `isRefetching` -- background refresh, cached data available → show data + subtle indicator
- `isFetching` -- any fetch in progress (includes both) → use for disabling actions

### Query Configuration Best Practices

```tsx
// Contract reads: moderate stale time (data changes on-chain after blocks)
useCallClause({
  // ...
  queryOptions: {
    enabled: !!address,        // Don't fetch until params are ready
    staleTime: 10_000,         // 10s = ~1 VeChain block
    refetchInterval: 30_000,   // Poll every 30s for live data
  },
});

// Indexer/API data: longer stale time
useQuery({
  queryKey: ['indexer', 'leaderboard'],
  queryFn: fetchLeaderboard,
  staleTime: 60_000,          // 1 minute
  gcTime: 5 * 60_000,         // Keep in cache 5 minutes
});

// Static data: cache aggressively
useQuery({
  queryKey: ['token', 'info', tokenAddress],
  queryFn: () => fetchTokenInfo(tokenAddress),
  staleTime: Infinity,         // Never refetch automatically
});
```

### Anti-Patterns

```tsx
// BAD: fetching in useEffect + useState (bypasses React Query)
const [balance, setBalance] = useState(null);
useEffect(() => {
  fetchBalance(address).then(setBalance);
}, [address]);

// GOOD: use React Query
const { data: balance } = useCallClause({ ... });

// BAD: duplicating server state in Zustand
const useStore = create((set) => ({
  tokenBalance: null,
  fetchBalance: async () => { ... set({ tokenBalance }) },
}));

// GOOD: React Query owns server state, Zustand owns UI state only

// BAD: missing enabled guard (fires with undefined params)
useCallClause({ method: 'balanceOf', args: [address] }); // address might be undefined!

// GOOD: guard with enabled
useCallClause({ method: 'balanceOf', args: [address], queryOptions: { enabled: !!address } });
```

---

## useThor (not useConnex)

`useConnex` is deprecated everywhere (including dapp-kit v2). Always use `useThor`:

```tsx
// VeChain Kit
import { useThor } from '@vechain/vechain-kit';

// dapp-kit v2
import { useThor } from '@vechain/dapp-kit-react';

const thor = useThor();
```

---

## Common Project Architecture (Turborepo)

Many VeChain dApps use a Turborepo monorepo. When the project follows this structure, respect these conventions:

```
root/
├── apps/
│   └── frontend/          # Next.js App Router
│       └── src/
│           ├── api/
│           │   ├── contracts/  # Contract read hooks (useCallClause wrappers)
│           │   └── indexer/    # Indexer/API query hooks
│           ├── app/            # Next.js App Router pages
│           └── components/
├── packages/
│   ├── contracts/          # Hardhat smart contracts
│   ├── config/             # Shared config (ESLint, TS, etc.)
│   ├── utils/              # Shared utilities
│   └── constants/          # Shared constants, addresses, ABIs
├── turbo.json
└── package.json
```

**Apply these conventions only when the project actually uses this structure.** Check for `turbo.json` or `"turbo"` in the root `package.json` to confirm.

### API Layer Convention
When the project has `src/api/contracts/`:
- Place each contract read hook in its own file (e.g., `useTokenBalance.ts`)
- Export all hooks from `src/api/contracts/index.ts`
- Indexer queries go in `src/api/indexer/`

---

## State Management Pattern

When the project uses React Query + Zustand:
- **Server state** (contract reads, indexer data): React Query via `useCallClause` or custom `useQuery` hooks
- **Client state** (UI state, form state, toggles): Zustand stores
- Never duplicate server state in Zustand -- let React Query be the source of truth

---

## Chakra UI Integration

When the project uses Chakra UI:
- VeChain Kit's peer dependency is `@chakra-ui/react@^2.8.2`
- Define theme in a central file (e.g., `src/app/theme/theme.ts`)
- Use component recipes for consistent styling (button.ts, card.ts, etc.)
- **Mobile-first**: design for small viewports first, add `md`/`lg` breakpoints for larger screens
- Use responsive props: `<Box p={{ base: 4, md: 8 }}>`

---

## i18n with react-i18next

When the project uses internationalization:
- Use `react-i18next` with flat JSON key-value translation files
- Interpolation: `{{variableName}}`
- VeChain Kit has built-in i18n; sync language with `useCurrentLanguage`

```tsx
import { useCurrentLanguage } from '@vechain/vechain-kit';
const { language, setLanguage } = useCurrentLanguage();
```

---

## Transaction UX Checklist

- Disable inputs while a transaction is pending
- Show transaction status via `TransactionModal` or `TransactionToast`
- Provide a transaction ID immediately after signing
- Track confirmation via `useTxReceipt`
- **Invalidate ALL affected React Query caches in `onTxConfirmed`** -- see [Cache Invalidation After Transactions](#cache-invalidation-after-transactions-critical). Think through every query that reads data changed by this transaction, including queries in other components (navbar, banners, badges, lists)
- Show actionable errors:
  - user rejected signing (`UserRejectedError`)
  - transaction reverted (`RevertReasonError` with reason)
  - insufficient VET for transfer
  - insufficient balance for gas fees (VET/VTHO/B3TR)
- Handle fee delegation failures gracefully (fallback or clear error)
