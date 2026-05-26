# Multi-Clause Transactions

## When to use

Use when the user asks about:

- Batching multiple operations in one transaction
- Atomic multi-step operations
- Sending to multiple recipients at once
- Combining contract calls with value transfers
- Multi-clause transaction patterns

## What are Multi-Clause Transactions?

Multi-clause transactions are a **unique VeChainThor feature** that allows a single transaction to contain multiple operations (clauses). Each clause has its own recipient, value, and data.

### Key Properties

- **Atomic execution**: All clauses succeed or all fail -- no partial execution
- **Sequential processing**: Clauses execute in the exact order defined
- **Single gas fee**: One transaction fee covers all clauses
- **Single signature**: The sender signs once for all operations

### Clause Structure

Each clause contains:
- `to` -- Recipient address (`null` for contract deployment)
- `value` -- Amount of VET to transfer (in wei)
- `data` -- Input data (for contract calls, `'0x'` for simple transfers)

## Basic Multi-Clause Examples

### Multiple VET Transfers

```typescript
import { Address, Clause, VET, Transaction, HexUInt } from '@vechain/sdk-core';
import { ThorClient } from '@vechain/sdk-network';

const thorClient = ThorClient.at('http://localhost:8669');

const clauses = [
    Clause.transferVET(Address.of('0xRecipient1...'), VET.of(100)),
    Clause.transferVET(Address.of('0xRecipient2...'), VET.of(200)),
    Clause.transferVET(Address.of('0xRecipient3...'), VET.of(300)),
];

const gasResult = await thorClient.gas.estimateGas(clauses, senderAddress);
const bestBlock = await thorClient.blocks.getBestBlockCompressed();

const body = {
    chainTag: 0x27, // testnet
    blockRef: bestBlock.id.slice(0, 18),
    expiration: 32,
    clauses,
    gasPriceCoef: 0,
    gas: gasResult.totalGas,
    dependsOn: null,
    nonce: Date.now(),
};

const signedTx = Transaction.of(body).sign(privateKey);
const rawTx = HexUInt.of(signedTx.encoded).toString();
const result = await thorClient.transactions.sendRawTransaction(rawTx);
```

### Mixed VET and VTHO Transfers

```typescript
import { Address, Clause, VET, VTHO } from '@vechain/sdk-core';

const clauses = [
    // Transfer VET
    Clause.transferVET(
        Address.of('0xRecipient...'),
        VET.of(1000)
    ),
    // Transfer VTHO
    Clause.transferVTHOToken(
        Address.of('0xRecipient...'),
        VTHO.of(500)
    ),
];
```

### Contract Calls with Value Transfer

```typescript
import { Clause, ABIContract } from '@vechain/sdk-core';

const clauses = [
    // First: approve token spending
    {
        to: tokenContractAddress,
        value: '0x0',
        data: ABIContract.encodeFunctionInput(
            tokenABI,
            'approve',
            [spenderAddress, amount]
        ),
    },
    // Second: call contract that uses the approved tokens
    {
        to: dexContractAddress,
        value: '0x0',
        data: ABIContract.encodeFunctionInput(
            dexABI,
            'swap',
            [tokenAddress, amount, minOutput]
        ),
    },
];
```

## Multi-Clause Reads (Batch Queries)

Read multiple contract values in a single RPC call:

```typescript
const thorClient = ThorClient.at('https://testnet.vechain.org');
const contract = thorClient.contracts.load(contractAddress, contractABI);

// Batch multiple read operations
const results = await thorClient.contracts.executeMultipleClausesCall([
    contract.clause.totalSupply(),
    contract.clause.name(),
    contract.clause.symbol(),
    contract.clause.decimals(),
    contract.clause.balanceOf(someAddress),
]);

const [totalSupply, name, symbol, decimals, balance] = results;
```

## Frontend Multi-Clause with VeChain Kit (preferred)

Pass an array of clauses to `useSendTransaction` (see the **vechain-kit** skill for the full hook API):

```tsx
const { sendTransaction } = useSendTransaction({
    signerAccountAddress: account?.address ?? '',
});

const handleBatch = async () => {
    await sendTransaction([
        { to: '0xRecipient1...', value: '0x' + (100e18).toString(16), data: '0x', comment: 'Send 100 VET' },
        { to: contractAddress, value: '0x0', data: encodedFunctionData, comment: 'Contract call', abi: contractFunctionABI },
        { to: '0xRecipient2...', value: '0x' + (50e18).toString(16), data: '0x', comment: 'Send 50 VET' },
    ]);
};
```

Handles both wallet and social login users automatically. Social login V3 smart accounts use `executeBatchWithAuthorization` under the hood.

## Frontend Multi-Clause with dapp-kit

If using dapp-kit instead of VeChain Kit:

```tsx
import { useSendTransaction } from '@vechain/dapp-kit-react';

function BatchOperation() {
    const { sendTransaction } = useSendTransaction();

    const handleBatch = async () => {
        const result = await sendTransaction({
            clauses: [
                { to: '0xRecipient1...', value: '0x' + (100e18).toString(16), data: '0x' },
                { to: contractAddress, value: '0x0', data: encodedFunctionData },
                { to: '0xRecipient2...', value: '0x' + (50e18).toString(16), data: '0x' },
            ],
            comment: 'Batch: transfer + contract call + transfer',
        });

        console.log('Transaction ID:', result.id);
    };

    return <button onClick={handleBatch}>Execute Batch</button>;
}
```

## Use Cases

### Token Airdrop
```typescript
const recipients = [
    { address: '0xAddr1...', amount: 100 },
    { address: '0xAddr2...', amount: 200 },
    { address: '0xAddr3...', amount: 150 },
];

const clauses = recipients.map(r => ({
    to: tokenContractAddress,
    value: '0x0',
    data: ABIContract.encodeFunctionInput(
        erc20ABI,
        'transfer',
        [r.address, ethers.parseEther(r.amount.toString())]
    ),
}));
```

### Approve + Deposit (DeFi Pattern)
```typescript
const clauses = [
    // Step 1: Approve vault to spend tokens
    {
        to: tokenAddress,
        value: '0x0',
        data: ABIContract.encodeFunctionInput(
            erc20ABI, 'approve', [vaultAddress, depositAmount]
        ),
    },
    // Step 2: Deposit into vault (uses approved tokens)
    {
        to: vaultAddress,
        value: '0x0',
        data: ABIContract.encodeFunctionInput(
            vaultABI, 'deposit', [depositAmount]
        ),
    },
];
```

### NFT Batch Mint
```typescript
const tokenURIs = ['ipfs://...1', 'ipfs://...2', 'ipfs://...3'];

const clauses = tokenURIs.map(uri => ({
    to: nftContractAddress,
    value: '0x0',
    data: ABIContract.encodeFunctionInput(
        nftABI, 'safeMint', [recipientAddress, uri]
    ),
}));
```

### Contract Deployment + Initialization
```typescript
const clauses = [
    // Deploy contract
    Clause.deployContract(contractBytecode),
    // Note: You cannot reference the deployed address in subsequent clauses
    // because the address is only known after execution.
    // For deploy + init, use a factory pattern instead.
];
```

## Gas Calculation

Multi-clause transactions follow VeChain's gas formula:

```
g_total = g_0 + SUM(g_type_i + g_data_i + g_vm_i)
```

Where:
- `g_0 = 5,000` (base transaction gas, paid once)
- `g_type = 16,000` per transfer clause; `48,000` per contract creation clause
- `g_data` = per-clause data cost
- `g_vm` = per-clause VM execution cost

### Estimating Gas
```typescript
const gasResult = await thorClient.gas.estimateGas(
    clauses,
    senderAddress,
    { gasPadding: 0.15 } // 15% safety margin
);

console.log('Total gas:', gasResult.totalGas);
console.log('Reverted clauses:', gasResult.revertReasons);
```

## Limitations and Gotchas

- **No cross-clause references**: A clause cannot reference the output (e.g., deployed contract address) of a previous clause
- **All-or-nothing**: If any clause reverts, the entire transaction reverts
- **Gas estimation**: Estimate gas for all clauses together, not individually
- **Receipt format**: The transaction receipt contains an `outputs` array with one entry per clause
- **Event ordering**: Events from clause N appear before events from clause N+1 in the receipt

## Receipt Handling

```typescript
const receipt = await thorClient.transactions.getTransactionReceipt(txId);

// Each clause has its own output in the receipt
for (let i = 0; i < receipt.outputs.length; i++) {
    const output = receipt.outputs[i];
    console.log(`Clause ${i}:`);
    console.log('  Events:', output.events.length);
    console.log('  Transfers:', output.transfers.length);
}

// Check if transaction reverted
if (receipt.reverted) {
    const reason = await thorClient.transactions.getRevertReason(txId);
    console.log('Revert reason:', reason);
}
```

## Best Practices

- Use multi-clause for logically related operations that should be atomic
- Estimate gas for the complete clause set, not individual clauses
- Keep clause count reasonable (excessive clauses increase gas cost)
- Combine with fee delegation for the best user experience
- Use multi-clause reads for efficient batch data fetching
- Handle the all-or-nothing nature in UI (inform users all operations are atomic)
