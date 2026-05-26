# Standalone Templates

Standalone mode: single Next.js app, no Turborepo, no contracts package.
All source files from `shared.md` go under `src/`.

## Directory structure

```text
{{PROJECT_NAME}}/
├── .github/workflows/deploy.yml
├── .env.example
├── .eslintrc.json
├── .gitignore
├── .nvmrc
├── next.config.js
├── package.json
├── tsconfig.json
└── src/
    ├── api/
    │   └── QueryProvider.ts
    ├── app/
    │   ├── ClientApp.tsx
    │   ├── layout.tsx
    │   ├── page.tsx
    │   ├── providers.tsx
    │   └── theme/
    │       └── theme.ts
    ├── components/
    │   ├── Navbar.tsx
    │   └── ui/
    │       ├── color-mode.tsx
    │       └── provider.tsx
    └── providers/
        └── VeChainProvider.tsx
```

## `package.json`

```json
{
  "name": "{{PROJECT_NAME}}",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev --turbo",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@chakra-ui/react": "3.30.0",
    "@emotion/react": "^11.14.0",
    "@tanstack/react-query": "^5.64.2",
    "@vechain/vechain-kit": "latest",
    "next": "14.2.25",
    "next-themes": "^0.4.6",
    "react": "^18",
    "react-dom": "^18",
    "react-icons": "^5.5.0"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "eslint": "^8",
    "eslint-config-next": "14.2.25",
    "typescript": "^5"
  },
  "engines": {
    "node": "20.x.x"
  },
  "packageManager": "yarn@1.22.22"
}
```

## `next.config.js`

```javascript
/** @type {import('next').NextConfig} */
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? ""

const nextConfig = {
  output: "export",
  basePath: basePath || undefined,
  assetPrefix: basePath ? `${basePath}/` : undefined,
  reactStrictMode: true,
  typescript: { ignoreBuildErrors: false },
  eslint: { ignoreDuringBuilds: true },
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
      }
    }
    return config
  },
}

module.exports = nextConfig
```

## `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "preserve",
    "noEmit": true,
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "isolatedModules": true,
    "incremental": true,
    "resolveJsonModule": true,
    "noUncheckedIndexedAccess": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": [".next", "node_modules", "out"]
}
```

## `.eslintrc.json`

```json
{
  "extends": "next/core-web-vitals"
}
```

## `.gitignore`

```text
node_modules/
.next/
out/
.env
.env.local
*.tsbuildinfo
next-env.d.ts
```

## `.github/workflows/deploy.yml`

Uses `/${{ github.event.repository.name }}` by default for GitHub Pages (`username.github.io/<repo-name>`).
Set to `""` if using a custom domain or if the repo is named `username.github.io`.
Note: `metadata.icons` and raw `<img src>` do NOT auto-prepend `basePath` — prefix them manually.

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: yarn

      - run: yarn install --frozen-lockfile

      - run: yarn build
        env:
          NEXT_PUBLIC_BASE_PATH: "/${{ github.event.repository.name }}"
          NEXT_PUBLIC_NETWORK: "{{NETWORK_TYPE}}"

      - uses: actions/upload-pages-artifact@v3
        with:
          path: out

  deploy:
    runs-on: ubuntu-latest
    needs: build
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - id: deploy
        uses: actions/deploy-pages@v4
```
