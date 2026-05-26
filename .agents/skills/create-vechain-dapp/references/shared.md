# Shared Templates

These files are identical for both standalone and monorepo modes.
In monorepo mode, place them under `apps/frontend/` instead of the project root.

## `.nvmrc`

```text
20
```

## Compatibility notes

### Chakra UI v3 + VeChain Kit

VeChain Kit uses Chakra UI v2 internally. Newer Chakra v3 releases can introduce CSS variable changes that break VeChain Kit's buttons and modals (wrong colors, missing styles). **Pin `@chakra-ui/react` to an exact version known to work** (currently `3.30.0`). Do NOT use `^` ranges.

### Webpack fallbacks

Some VeChain packages import Node.js modules (`fs`, `net`, `tls`) that don't exist in the browser. The `next.config.js` must include webpack fallbacks for client-side builds. See the `next.config.js` template in standalone.md or monorepo.md.

### Static asset paths with basePath

Next.js `basePath` is NOT auto-prepended to `metadata.icons`, `<img src>`, or any raw string paths. Use `process.env.NEXT_PUBLIC_BASE_PATH` prefix for these. The `<Image>` component from `next/image` DOES auto-prepend `basePath`.

## `.env.example`

```text
NEXT_PUBLIC_NETWORK={{NETWORK_TYPE}}
NEXT_PUBLIC_BASE_PATH=
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=
```

## `src/app/theme/theme.ts`

```typescript
import { createSystem, defaultConfig, defineConfig } from "@chakra-ui/react"

const config = defineConfig({
  cssVarsPrefix: "app",
  theme: {
    semanticTokens: {
      colors: {
        bg: {
          primary: { value: { _light: "#FFFFFF", _dark: "#0A0A0A" } },
          secondary: { value: { _light: "#F5F5F5", _dark: "#141414" } },
        },
        border: {
          primary: { value: { _light: "{colors.gray.200}", _dark: "{colors.gray.800}" } },
        },
        text: {
          subtle: { value: { _light: "{colors.gray.600}", _dark: "{colors.gray.400}" } },
        },
      },
    },
  },
})

export default createSystem(defaultConfig, config)
```

## `src/components/ui/color-mode.tsx`

```tsx
"use client"

import { Button, ClientOnly, Skeleton, type IconButtonProps } from "@chakra-ui/react"
import { ThemeProvider, useTheme, type ThemeProviderProps } from "next-themes"
import * as React from "react"
import { LuMoon, LuSun } from "react-icons/lu"

export type ColorMode = "light" | "dark"
export type ColorModeProviderProps = ThemeProviderProps

export interface UseColorModeReturn {
  colorMode: ColorMode
  setColorMode: (colorMode: ColorMode) => void
  toggleColorMode: () => void
}

export function ColorModeProvider(props: ThemeProviderProps) {
  return <ThemeProvider attribute="class" disableTransitionOnChange {...props} />
}

export function useColorMode(): UseColorModeReturn {
  const { resolvedTheme, setTheme, forcedTheme } = useTheme()
  const colorMode = forcedTheme ?? resolvedTheme
  return {
    colorMode: (colorMode ?? "light") as ColorMode,
    setColorMode: setTheme,
    toggleColorMode: () => setTheme(resolvedTheme === "dark" ? "light" : "dark"),
  }
}

export function useColorModeValue<T>(light: T, dark: T) {
  const { colorMode } = useColorMode()
  return colorMode === "dark" ? dark : light
}

function ColorModeIcon() {
  const { colorMode } = useColorMode()
  return colorMode === "light" ? <LuMoon /> : <LuSun />
}

interface ColorModeButtonProps extends Omit<IconButtonProps, "aria-label"> {}

export const ColorModeButton = React.forwardRef<HTMLButtonElement, ColorModeButtonProps>(
  function ColorModeButton(props, ref) {
    const { toggleColorMode } = useColorMode()
    return (
      <ClientOnly fallback={<Skeleton boxSize="8" />}>
        <Button
          onClick={toggleColorMode}
          variant="ghost"
          aria-label="Toggle color mode"
          size="sm"
          ref={ref}
          {...props}
          css={{ _icon: { width: "4", height: "4" } }}>
          <ColorModeIcon />
        </Button>
      </ClientOnly>
    )
  },
)
```

## `src/components/ui/provider.tsx`

```tsx
"use client"

import { ChakraProvider } from "@chakra-ui/react"
import theme from "@/app/theme/theme"
import { ColorModeProvider, type ColorModeProviderProps } from "./color-mode"

export function Provider(props: ColorModeProviderProps) {
  return (
    <ChakraProvider value={theme}>
      <ColorModeProvider {...props} />
    </ChakraProvider>
  )
}
```

## `src/providers/VeChainProvider.tsx`

```tsx
"use client"

import dynamic from "next/dynamic"
import { useColorMode } from "@/components/ui/color-mode"

const VeChainKitProvider = dynamic(
  () => import("@vechain/vechain-kit").then(mod => mod.VeChainKitProvider),
  { ssr: false },
)

interface Props {
  readonly children: React.ReactNode
}

export function VeChainProvider({ children }: Props) {
  const { colorMode } = useColorMode()
  const isDarkMode = colorMode === "dark"
  const networkType = (process.env.NEXT_PUBLIC_NETWORK ?? "test") as "main" | "test"

  return (
    <VeChainKitProvider
      dappKit={{
        allowedWallets: ["veworld", "wallet-connect"],
        walletConnectOptions: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID
          ? {
              projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID,
              metadata: {
                name: "{{PROJECT_TITLE}}",
                description: "{{PROJECT_TITLE}} — VeChain dApp",
                url: typeof window !== "undefined" ? window.location.origin : "",
                icons: [],
              },
            }
          : undefined,
      }}
      loginMethods={[
        { method: "vechain", gridColumn: 4 },
        { method: "dappkit", gridColumn: 4 },
      ]}
      darkMode={isDarkMode}
      language="en"
      network={{ type: networkType }}>
      {children}
    </VeChainKitProvider>
  )
}
```

## `src/api/QueryProvider.ts`

```typescript
import { QueryClient } from "@tanstack/react-query"

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 0,
      staleTime: 60_000,
      refetchOnWindowFocus: false,
    },
  },
})
```

## `src/app/providers.tsx`

```tsx
"use client"

import { QueryClientProvider } from "@tanstack/react-query"
import { queryClient } from "@/api/QueryProvider"
import { Provider } from "@/components/ui/provider"
import { VeChainProvider } from "@/providers/VeChainProvider"

export function Providers({ children }: { readonly children: React.ReactNode }) {
  return (
    <Provider>
      <QueryClientProvider client={queryClient}>
        <VeChainProvider>{children}</VeChainProvider>
      </QueryClientProvider>
    </Provider>
  )
}
```

## `src/app/ClientApp.tsx`

```tsx
"use client"

import { Container, Flex, VStack } from "@chakra-ui/react"
import { Navbar } from "@/components/Navbar"
import { Providers } from "./providers"

export function ClientApp({ children }: { children: React.ReactNode }) {
  return (
    <Providers>
      <VStack minH="100vh" gap={0} align="stretch">
        <Navbar />
        <Flex flex={1}>
          <Container flex={1} my={{ base: 4, md: 10 }} px={4} maxW="breakpoint-xl">
            {children}
          </Container>
        </Flex>
      </VStack>
    </Providers>
  )
}
```

## `src/app/layout.tsx`

```tsx
import type { Metadata } from "next"
import dynamic from "next/dynamic"
import { Flex, Spinner } from "@chakra-ui/react"

const ClientApp = dynamic(() => import("./ClientApp").then(mod => mod.ClientApp), {
  ssr: false,
  loading: () => (
    <Flex minH="100vh" align="center" justify="center">
      <Spinner size="lg" />
    </Flex>
  ),
})

export const metadata: Metadata = {
  title: "{{PROJECT_TITLE}}",
  description: "{{PROJECT_TITLE}} — a VeChain dApp",
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <ClientApp>{children}</ClientApp>
      </body>
    </html>
  )
}
```

## `src/app/page.tsx`

```tsx
"use client"

import { Heading, Text, VStack } from "@chakra-ui/react"

export default function HomePage() {
  return (
    <VStack gap={6} py={12} textAlign="center">
      <Heading size="2xl">{"{{PROJECT_TITLE}}"}</Heading>
      <Text textStyle="lg" color="fg.muted">
        {"Built on VeChain with Next.js, Chakra UI, and VeChain Kit"}
      </Text>
    </VStack>
  )
}
```

## `src/components/Navbar.tsx`

Uses `WalletButton` from VeChain Kit (imported directly since the parent
`ClientApp` is already client-only via dynamic import).

```tsx
"use client"

import { Box, Flex, Heading, HStack } from "@chakra-ui/react"
import { WalletButton } from "@vechain/vechain-kit"
import { ColorModeButton } from "@/components/ui/color-mode"

export function Navbar() {
  return (
    <Box as="nav" bg="bg.secondary" px={4} py={3} borderBottomWidth="1px">
      <Flex maxW="breakpoint-xl" mx="auto" align="center" justify="space-between">
        <Heading size="md" fontWeight="bold">
          {"{{PROJECT_TITLE}}"}
        </Heading>
        <HStack gap={2}>
          <ColorModeButton />
          <WalletButton />
        </HStack>
      </Flex>
    </Box>
  )
}
```
