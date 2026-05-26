# VeChain Kit — Theming & Compatibility

## When to use

Use when the user asks about: theming VeChain Kit, customizing colors/fonts/buttons, Chakra UI compatibility, bottom sheet on mobile, glass effects, or webpack fallbacks.

---

## Theming

Minimal config: set `modal.backgroundColor` and `textColor` — all other colors auto-derive. Import `VechainKitThemeConfig` for type safety.

```tsx
import type { VechainKitThemeConfig } from '@vechain/vechain-kit';

const theme: VechainKitThemeConfig = {
  modal: {
    backgroundColor: isDarkMode ? '#1f1f1e' : '#ffffff',
    useBottomSheetOnMobile: true, // Slide-up bottom sheet on mobile instead of centered modal
    // border, backdropFilter, rounded are optional
  },
  textColor: isDarkMode ? 'rgb(223, 223, 221)' : '#2e2e2e',
  // Brand accent — spinner top arc, focus rings, "Waiting for signature…"
  // headline in the connect modal, and the email-submit link when valid.
  // Defaults: '#3b82f6' (light) / '#60a5fa' (dark).
  accent: '#ff6600',
  overlay: {
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    blur: 'blur(3px)',
  },
  buttons: {
    primaryButton: { bg: '#3182CE', color: 'white', border: 'none' },
    secondaryButton: { bg: 'rgba(255,255,255,0.05)', color: '#fff', border: 'none' },
    tertiaryButton: { bg: 'transparent', color: '#fff', border: 'none' },
    loginButton: { bg: 'transparent', color: '#fff', border: '1px solid rgba(255,255,255,0.1)' },
  },
  fonts: {
    family: 'Inter, sans-serif',
    sizes: { small: '12px', medium: '14px', large: '16px' },
    weights: { normal: 400, medium: 500, bold: 700 },
  },
  effects: {
    glass: { enabled: true, intensity: 'low' }, // 'low' | 'medium' | 'high'
  },
};

<VeChainKitProvider theme={theme} {...otherProps}>
```

## Theme API reference

| Prop | Shape | Notes |
|------|-------|-------|
| `modal` | `{ backgroundColor, border, backdropFilter, rounded, useBottomSheetOnMobile }` | Modal container. `backgroundColor` auto-derives card (80%), header (90%), secondary/tertiary, and border colors. `useBottomSheetOnMobile`: slide-up bottom sheet on mobile |
| `textColor` | `string` | Auto-derives primary (100%), secondary (70%), tertiary (50%) text |
| `accent` | `string` | Brand accent. Drives the connect modal's spinner top arc, focus rings, "Waiting for signature…" headline, and the email-submit link when the address is valid. Default `#3b82f6` (light) / `#60a5fa` (dark) |
| `overlay` | `{ backgroundColor, blur }` | Modal overlay backdrop |
| `buttons` | `{ primaryButton, secondaryButton, tertiaryButton, loginButton }` | Each: `{ bg, color, border, backdropFilter?, rounded? }` |
| `fonts` | `{ family, sizes?, weights? }` | `sizes`: `{ small, medium, large }`. `weights`: `{ normal, medium, bold }`. Scoped to Kit components only — does not affect host app |
| `effects` | `{ glass: { enabled, intensity } }` | Glass morphism; intensity: `'low'` / `'medium'` / `'high'` |

**Common mistakes:**

- `buttons.primary.background` does not exist — use `buttons.primaryButton.bg`
- `font.family` does not exist — use `fonts.family`
- `hoverBg` does not exist in the types

## Chakra UI v3 compatibility

VeChain Kit uses Chakra UI v2 internally. When the host app uses Chakra v3, **pin `@chakra-ui/react` to an exact working version** (currently `3.30.0`). Newer v3 releases can change CSS variable generation and break VeChain Kit's button/modal styling (wrong colors, missing backgrounds). Do NOT use `^` ranges like `^3.26.0`.

### `useToken` returns a snapshot, not a CSS variable

Chakra v3's `useToken('colors', 'bg.primary')` returns the **resolved literal color** at render time (e.g. `#1B1D1F`), NOT a CSS variable reference. If you pipe that snapshot into the Kit's `theme` prop, the Kit's modal/card/sticky-header colors **freeze in whichever mode Chakra evaluated first** and stop tracking host theme toggles (next-themes, html.dark, etc.). Only Kit components reading `useVeChainKitConfig().darkMode` directly (e.g. the VeWorld button) will react.

**Wrong:**

```tsx
// ❌ freezes to whatever mode Chakra evaluated first
const [bgPrimary, primaryDefault] = useToken('colors', [
  'bg.primary',
  'actions.primary.default',
])
<VeChainKitProvider theme={{ modal: { backgroundColor: bgPrimary }, ... }} />
```

**Right — use Chakra v3's `sys.token.var(...)` resolver so the Kit gets a `var(...)` reference that flips at paint time:**

```tsx
import { useChakraContext } from '@chakra-ui/react'

const sys = useChakraContext()
const tokVar = (p: string) => sys.token.var(`colors.${p}`) as string

const bgPrimary      = tokVar('bg.primary')              // 'var(--vbd-colors-bg-primary)'
const primaryDefault = tokVar('actions.primary.default')
// …etc

<VeChainKitProvider theme={{ modal: { backgroundColor: bgPrimary }, ... }} />
```

Hardcoding `'var(--vbd-colors-bg-primary)'` strings works too if the `cssVarsPrefix` is fixed.

To verify after wiring: in DevTools, `--chakra-colors-vechain-kit-modal` should resolve to `var(--your-prefix-...)` (and switch on theme toggle), not to a hex literal.

A full repro lives at `examples/next-chakra-v3/` in [vechain/vechain-kit](https://github.com/vechain/vechain-kit).

## Webpack fallbacks for Next.js

Some VeChain packages (e.g. `@vechain/vebetterdao-relayer-node`) import Node.js modules (`fs`, `net`, `tls`). For Next.js client-side builds, add webpack fallbacks in `next.config.js`:

```js
webpack: (config, { isServer }) => {
  if (!isServer) {
    config.resolve.fallback = { ...config.resolve.fallback, fs: false, net: false, tls: false }
  }
  return config
},
```
