# Fee Delegation (VIP-191)

## When to use

Use when the user asks about:
- Gasless transactions (users don't pay VTHO)
- Sponsored transactions, fee abstraction for onboarding
- Meta-transactions on VeChain, VIP-191 designated gas payer
- Generic Delegator, gas estimation, transaction cost

## VIP-191: Designated Gas Payer

- Operates at the **transaction level**
- Flexible: per-transaction sponsorship decisions
- Both sender and sponsor must be online
- Requires `reserved.features = 1` in the transaction body
- Best for: selective sponsorship, promotional campaigns, onboarding flows

## VIP-191 Implementation

### Flow
1. User creates an unsigned transaction with `reserved: { features: 1 }`
2. User sends the unsigned transaction to the gas payer's service
3. Gas payer evaluates whether to sponsor (checks criteria)
4. Gas payer returns their signature
5. User combines both signatures and submits to the blockchain

### Backend: Sign as Both Sender and Gas Payer

```typescript
import {
    Address, Clause, VET, Transaction, HexUInt,
    Mnemonic, networkInfo
} from '@vechain/sdk-core';
import { ThorClient } from '@vechain/sdk-network';

const thorClient = ThorClient.at('http://localhost:8669');

// Build clauses
const clauses = [
    Clause.transferVET(
        Address.of('0x7567d83b7b8d80addcb281a71d54fc7b3364ffed'),
        VET.of(10000)
    )
];

// Estimate gas
const gasResult = await thorClient.gas.estimateGas(clauses, senderAddress);

// Get current block for blockRef
const bestBlock = await thorClient.blocks.getBestBlockCompressed();

// Build transaction body with fee delegation enabled
const body = {
    chainTag: networkInfo.mainnet.chainTag,
    blockRef: bestBlock.id.slice(0, 18),
    expiration: 32,
    clauses,
    gasPriceCoef: 0,
    gas: gasResult.totalGas,
    dependsOn: null,
    nonce: Date.now(),
    reserved: {
        features: 1  // Enable VIP-191 fee delegation
    }
};

// Sign with both sender and gas payer private keys
const signedTransaction = Transaction.of(body).signAsSenderAndGasPayer(
    HexUInt.of(senderPrivateKey).bytes,
    HexUInt.of(gasPayerPrivateKey).bytes
);

// Send
const rawTx = HexUInt.of(signedTransaction.encoded).toString();
const result = await thorClient.transactions.sendRawTransaction(rawTx);
const receipt = await thorClient.transactions.waitForTransaction(result.id);
```

### Using a Delegation URL (sponsor service)

```typescript
import { VeChainProvider, ProviderInternalBaseWallet } from '@vechain/sdk-network';

const provider = new VeChainProvider(
    thorClient,
    new ProviderInternalBaseWallet(
        [{ privateKey: senderPrivateKey, address: senderAddress }],
        {
            gasPayer: {
                delegateUrl: 'https://sponsor-testnet.vechain.energy/by/YOUR_PROJECT_ID'
            }
        }
    ),
    true  // isDelegated = true
);

// Transactions sent via this provider are automatically fee-delegated
const signer = await provider.getSigner(senderAddress);
```

### Frontend: Fee Delegation via VeChain Kit

VeChain Kit v2 has two fee delegation modes:

#### 1. Generic Delegator (default -- no cost to app owner)

VeChain Kit auto-enables the Generic Delegator when social login (Privy) or VeChain/ecosystem login is detected. **No configuration needed** -- users pay their own gas fees using VET, VTHO, or B3TR tokens. The app owner pays nothing.

Default gas token priority: VET → B3TR → VTHO. Users can change this in the VeChain Kit settings UI.

#### 2. App-Sponsored Delegation (app owner pays VTHO)

To sponsor transactions yourself, configure a `delegatorUrl`:

```tsx
<VeChainKitProvider
  feeDelegation={{
    delegatorUrl: 'https://your-delegator.com/delegate',
    delegateAllTransactions: true, // true = all users, false = social login only
  }}
>
```

#### Per-Transaction Sponsorship Control

Override delegation on individual transactions via the `delegationUrl` parameter:

```tsx
const { sendTransaction } = useSendTransaction({
  signerAccountAddress: account?.address ?? '',
});

// Sponsor this specific transaction
await sendTransaction(clauses, 'https://your-delegator.com/delegate');

// Or let the user pay (Generic Delegator)
await sendTransaction(clauses);
```

#### Gas Estimation (Generic Delegator)

When using the Generic Delegator, show users what they'll pay before confirming:

```tsx
import { useGenericDelegatorFeeEstimation } from '@vechain/vechain-kit';

const { data: estimation } = useGenericDelegatorFeeEstimation({
  clauses,
  tokens: ['VET', 'B3TR', 'VTHO'],  // Priority order
});
// estimation: { estimatedGas, transactionCost, serviceFee, totalGasUsed, usedToken }
```

#### Transaction Fee UX (Generic Delegator)

When using the Generic Delegator, implement these alerts:
- **Transaction confirmation**: Show the exact amount of VET/VTHO/B3TR that will be deducted
- **Insufficient funds**: Alert if the user lacks balance to cover fees, with the required amount

See the **vechain-kit** skill (`references/kit-hooks.md`) for the full `useSendTransaction` API.

### Frontend: Fee Delegation via dapp-kit

If using dapp-kit instead of VeChain Kit, configure delegation at the provider level:

```tsx
<DAppKitProvider
  nodeUrl="https://testnet.vechain.org"
  genesis="test"
  usePersistence={true}
>
```

Then use `useSendTransaction` from dapp-kit with a delegation URL:
```tsx
import { useSendTransaction } from '@vechain/dapp-kit-react';

function DelegatedTransaction() {
  const { sendTransaction } = useSendTransaction();

  const handleSend = async () => {
    const result = await sendTransaction({
      clauses: [{ to: '0x...', value: '0x0', data: encodedCallData }],
      comment: 'This transaction is sponsored',
      delegatorUrl: 'https://sponsor-testnet.vechain.energy/by/YOUR_PROJECT_ID',
    });

    console.log('Transaction ID:', result.id);
  };

  return <button onClick={handleSend}>Send (Gasless)</button>;
}
```

### Hardhat Configuration with Fee Delegation

```typescript
// hardhat.config.ts
vechain_testnet_delegated: {
  url: 'https://testnet.vechain.org',
  accounts: {
    mnemonic: process.env.MNEMONIC || '',
    count: 3,
    path: VET_DERIVATION_PATH
  },
  delegate: {
    url: 'https://sponsor-testnet.vechain.energy/by/YOUR_PROJECT_ID'
  },
  gas: 'auto',
  gasPrice: 'auto'
}
```

## Building a Gas Payer Service

For production VIP-191 deployments, build a service that:

1. **Receives** unsigned transactions from users
2. **Validates** the transaction (whitelist contracts, check amounts, rate limit)
3. **Signs** as gas payer if approved
4. **Returns** the gas payer signature

### Example validation logic
```typescript
function shouldSponsor(tx: TransactionBody): boolean {
  // Only sponsor interactions with known contracts
  const allowedContracts = ['0x...', '0x...'];

  for (const clause of tx.clauses) {
    if (!allowedContracts.includes(clause.to?.toLowerCase() ?? '')) {
      return false;
    }
    // Don't sponsor VET transfers
    if (BigInt(clause.value) > 0n) {
      return false;
    }
  }

  return true;
}
```

## Fee Delegation with vechain.energy (managed service)

For quick setup without building your own service:

1. Go to [vechain.energy](https://vechain.energy/)
2. Create a sponsorship project
3. Whitelist the smart contract addresses
4. For VeChain Kit smart accounts, whitelist:
   - **Mainnet**: `0xD7B96cAC488fEE053daAf8dF74f306bBc237D3f5`
   - **Testnet**: `0x7C5114ef27a721Df187b32e4eD983BaB813B81Cb`
5. Enable email alerts for low VTHO balance
6. Use the generated delegation URL in your provider config

## UX and Security Checklist

**App-sponsored delegation:**
- Always show the user that their transaction is sponsored (no hidden fees)
- Rate-limit sponsorship to prevent abuse
- Whitelist contracts and functions eligible for sponsorship
- Monitor VTHO balance of the gas payer account
- Set reasonable gas limits to prevent griefing
- Log all sponsored transactions for auditing
- Handle delegation service downtime gracefully

**Generic Delegator (user-paid):**
- Show transaction cost estimate before confirmation (use `useGenericDelegatorFeeEstimation`)
- Alert users when they have insufficient balance for fees
- Sponsoring transactions via app-sponsored delegation is still recommended to improve UX
