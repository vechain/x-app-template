# Deep Link and Platform Setup

## Overview

`@vechain/react-native-wallet-link` uses deep links for app-to-app communication with VeWorld. When your app requests a wallet operation, it opens VeWorld via a deep link. VeWorld processes the request and redirects back to your app using the configured `redirectUrl`.

## How it works

1. Your app calls a hook method (e.g., `connect(publicKey)`)
2. The library constructs a VeWorld deep link URL with encrypted parameters
3. `Linking.openURL()` opens VeWorld
4. VeWorld processes the request and redirects back via your app's URL scheme
5. `VeWorldProvider` listens for incoming deep links and dispatches to the appropriate callback

## Expo Setup

### app.json / app.config.js

Configure your URL scheme in the Expo config:

```json
{
  "expo": {
    "scheme": "myapp",
    "ios": {
      "bundleIdentifier": "com.mycompany.myapp",
      "infoPlist": {
        "CFBundleURLTypes": [
          {
            "CFBundleURLSchemes": ["myapp"]
          }
        ]
      }
    },
    "android": {
      "package": "com.mycompany.myapp",
      "intentFilters": [
        {
          "action": "VIEW",
          "data": [{ "scheme": "myapp" }],
          "category": ["DEFAULT", "BROWSABLE"]
        }
      ]
    }
  }
}
```

### Expo Router deep link handling

For Expo Router apps, create `app/+native-intent.tsx` to handle incoming deep links:

```typescript
// app/+native-intent.tsx
import { type NativeIntent } from 'expo-router';
import { isVeWorldResponse } from '@vechain/react-native-wallet-link';

export function redirectSystemPath({ path }: { path: string }): NativeIntent | string {
  // Let VeWorld responses pass through to VeWorldProvider
  if (isVeWorldResponse(path)) {
    return path;
  }
  // Handle other deep links normally
  return path;
}
```

### VeWorldProvider redirectUrl

For Expo projects, install `expo-linking` and use `createURL()` to generate the redirect URL. This ensures the correct URL is produced across Expo Go, dev clients, and production builds:

```bash
npx expo install expo-linking
```

```tsx
import { createURL } from 'expo-linking';

const redirectUrl = createURL('/');

<VeWorldProvider
  redirectUrl={redirectUrl}
  // ... other props
>
```

For bare React Native projects (without Expo), use a hardcoded scheme:

```tsx
<VeWorldProvider
  redirectUrl="myapp://"
  // ... other props
>
```

The library appends the operation path automatically (e.g., `myapp://connect`, `myapp://sign-transaction`).

## Bare React Native — iOS Setup

### Info.plist

Add URL types to `ios/<AppName>/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

### Universal Links (optional)

For HTTPS universal links, add an associated domains entitlement:

1. In Xcode: Signing & Capabilities → + Associated Domains
2. Add `applinks:myapp.com`
3. Host an `apple-app-site-association` file at `https://myapp.com/.well-known/apple-app-site-association`

## Bare React Native — Android Setup

### AndroidManifest.xml

Add an intent filter to your main activity in `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
  android:name=".MainActivity"
  android:launchMode="singleTask">
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" />
  </intent-filter>
</activity>
```

> **IMPORTANT**: Use `android:launchMode="singleTask"` to ensure deep link callbacks return to the existing app instance instead of creating a new one.

## Redirect URL Patterns

The library generates redirect URLs by appending the operation type:

| Operation | Redirect path |
|-----------|---------------|
| Connect | `myapp://connect` |
| Disconnect | `myapp://disconnect` |
| Sign Transaction | `myapp://sign-transaction` |
| Sign Certificate | `myapp://sign-certificate` |
| Sign Typed Data | `myapp://sign-typed-data` |

The `VeWorldProvider` parses these paths to determine which callback to invoke.

## Multiple redirect prefixes

You can configure multiple deep link prefixes when VeWorldProvider supports both custom schemes and universal links:

```tsx
// The redirectUrl should use your custom scheme
<VeWorldProvider
  redirectUrl="myapp://"
  // ...
>
```

## Debugging deep links

### iOS

```bash
# Test deep link from terminal
xcrun simctl openurl booted "myapp://connect?data=test"
```

### Android

```bash
# Test deep link from terminal
adb shell am start -a android.intent.action.VIEW -d "myapp://connect?data=test"
```

### Expo

```bash
# Test with Expo CLI
npx uri-scheme open "myapp://connect" --ios
npx uri-scheme open "myapp://connect" --android
```

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| VeWorld opens but never redirects back | URL scheme not configured | Verify scheme in Info.plist / AndroidManifest.xml / app.json |
| App opens a new instance on redirect | Missing `singleTask` launch mode | Set `android:launchMode="singleTask"` on Android |
| Callback not firing | `VeWorldProvider` not mounted | Ensure provider wraps the entire app above navigation |
| `crypto.getRandomValues` error | Missing polyfill | `import 'react-native-get-random-values'` at the top of your entry file |
