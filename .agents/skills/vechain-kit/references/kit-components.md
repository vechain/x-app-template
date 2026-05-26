# VeChain Kit — Components & Modals

## When to use

Use when the user asks about: WalletButton, TransactionModal, TransactionToast, modal hooks, isolated views, or VeChain Kit UI components.

---

## WalletButton

Acts as login button when disconnected and account button when connected.

```tsx
import { WalletButton } from '@vechain/vechain-kit';

<WalletButton mobileVariant="icon" desktopVariant="iconAndDomain" />

// Custom styling via buttonStyle (Chakra UI style props)
<WalletButton
  mobileVariant="iconDomainAndAssets"
  desktopVariant="iconDomainAndAssets"
  buttonStyle={{
    background: '#f08098',
    color: 'white',
    border: '2px solid #000',
    _hover: { background: '#db607a' },
  }}
/>
```

Variants: `icon` | `iconAndDomain` | `iconDomainAndAddress` | `iconDomainAndAssets`

Note: some variants adapt based on available data (e.g. `iconDomainAndAssets` only shows assets if the user has any).

## TransactionModal

```tsx
import { TransactionModal, useTransactionModal } from '@vechain/vechain-kit';

const { open, close, isOpen } = useTransactionModal();

<TransactionModal
  isOpen={isOpen}
  onClose={close}
  status={status}
  txReceipt={txReceipt}
  txError={error}
  onTryAgain={handleTryAgain}
  uiConfig={{
    title: 'Confirm Transaction',
    description: 'Sending tokens...',
    showShareOnSocials: true,
    showExplorerButton: true,
    isClosable: true,
  }}
/>
```

## Modal Hooks

All modal hooks return `{ open, close, isOpen }`. Pass `{ isolatedView: true }` to `open()` to prevent the user from navigating to other Kit sections.

```tsx
import {
  useAccountModal, useProfileModal, useSendTokenModal,
  useReceiveModal, useConnectModal, useDAppKitWalletModal,
  useAccountCustomizationModal, useAccessAndSecurityModal,
  useChooseNameModal, useUpgradeSmartAccountModal,
  useWalletModal, useTransactionToast,
  useExploreEcosystemModal, useNotificationsModal, useFAQModal,
} from '@vechain/vechain-kit';

const { open: openProfile } = useProfileModal();
openProfile({ isolatedView: true }); // Prevent navigation to other kit sections

// Wallet-only connection (bypasses social login)
const { open: openWalletModal } = useDAppKitWalletModal();
```

**Account:** `useAccountModal`, `useProfileModal`, `useAccountCustomizationModal`, `useAccessAndSecurityModal`, `useChooseNameModal`, `useUpgradeSmartAccountModal`
**Wallet/Connection:** `useConnectModal`, `useWalletModal`, `useDAppKitWalletModal`
**Transaction:** `useTransactionModal`, `useTransactionToast`, `useSendTokenModal`, `useReceiveModal`
**Features:** `useExploreEcosystemModal`, `useNotificationsModal`, `useFAQModal`

**VeWorld mobile:** When the app is accessed from VeWorld's in-app browser, VeWorld is automatically enforced as the primary authentication method.
