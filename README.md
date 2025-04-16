# X-App Template for Vechain

A simple application template for building Vechain-based applications with wallet connectivity and basic data submission.

## Overview

This X-App template provides a basic application stack with:

- **Frontend**: React application using Vite and Chakra UI with Vechain dapp-kit for wallet connections
- **Backend**: NestJS server with simple API endpoints

## Requirements

Before getting started, ensure you have the following installed:

- **Node.js** (v18 or later)
- **Yarn** (package manager)

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd x-app-template
   ```

2. Install dependencies:
   ```bash
   yarn install
   ```

## How It Works

This application demonstrates a simple flow where:

1. Users connect their Vechain wallet
2. Users can upload receipt images through the Dropzone component
3. The backend receives the uploaded image and validates it
4. The frontend displays the validation results

### Architecture

- **Frontend (`/apps/frontend`)**: React application with Chakra UI and Vechain dapp-kit
  - Uses React Dropzone for file uploads
  - Connects to Vechain testnet wallets
  - Provides a clean, responsive UI

- **Backend (`/apps/backend`)**: NestJS server with basic API endpoints
  - Provides user-related functionality
  - Includes a validation endpoint for receipt claims

## Running Locally

### 1. Start the Backend

```bash
cd apps/backend
yarn start:dev
```

This will start the NestJS server on the default port.

### 2. Start the Frontend

In a new terminal:

```bash
cd apps/frontend
yarn dev
```

This will start:
- Frontend at http://localhost:8082/

## Project Commands

### Frontend Commands

- `yarn dev`: Start development server (port 8082)
- `yarn build`: Build the frontend for production
- `yarn lint`: Run linting
- `yarn lint:fix`: Fix linting issues
- `yarn preview`: Preview the production build

### Backend Commands

- `yarn start:dev`: Start development server with hot reload
- `yarn start`: Start the server in production mode
- `yarn build`: Build the backend for production
- `yarn lint`: Run linting
- `yarn test`: Run tests

## Project Structure

```
x-app-template/
├─ apps/
│  ├─ backend/             # NestJS backend
│  │  ├─ src/              # Source code
│  │  │  ├─ user/          # User module with controllers and services
│  │  │  └─ ...            # Main application files
│  ├─ frontend/            # React frontend
│  │  ├─ src/              # Source code
│  │  │  ├─ components/    # UI components (Dropzone, Navbar, etc.)
│  │  │  ├─ networking/    # API communication
│  │  │  ├─ hooks/         # React hooks
│  │  │  └─ ...            # Other app files
├─ packages/               # Shared packages
├─ package.json            # Root package.json with workspace configuration
└─ ...                     # Configuration files

## Deploying to VeBetterDAO Testnet

To deploy your application to work with the VeBetterDAO testnet, follow these steps:

### 1. Build the Frontend for Production

```bash
cd apps/frontend
yarn build
```

This will generate optimized production files in the `dist` directory.

### 2. Build the Backend for Production

```bash
cd apps/backend
yarn build
```

This will generate production-ready files in the `dist` directory.

### 3. Configure Frontend for Testnet

Make sure your frontend is configured to connect to the Vechain testnet:

- The `DAppKitProvider` in `App.tsx` should have:
  ```jsx
  <DAppKitProvider
    usePersistence
    requireCertificate={false}
    genesis="test"
    nodeUrl="https://testnet.vechain.org/"
    logLevel={"DEBUG"}
  >
  ```

### 4. Deploy the Backend

You can deploy the NestJS backend to any Node.js hosting service, such as:
- Heroku
- Digital Ocean
- AWS Elastic Beanstalk
- Vercel

Example deployment to Heroku:
```bash
# Install Heroku CLI first
heroku create your-app-name-backend
git init
heroku git:remote -a your-app-name-backend
git add .
git commit -m "Deploy backend"
git push heroku main
```

### 5. Deploy the Frontend

Deploy the built frontend files to any static hosting service, such as:
- Netlify
- Vercel
- GitHub Pages
- AWS S3

Example deployment to Netlify:
```bash
# Install Netlify CLI
npm install netlify-cli -g
cd apps/frontend
netlify deploy --prod --dir=dist
```

### 6. Update Environment Variables

Update the `config.ts` file in the frontend to point to your deployed backend:

```typescript
// apps/frontend/src/config.ts
export const backendURL = "https://your-deployed-backend-url.com";
```

Your application should now be working with the VeBetterDAO testnet and accessible to users online.

## Additional Resources

- [Vechain Developer Resources](https://docs.vechain.org/developer-resources/sdks-and-providers/dapp-kit)
- [NestJS Documentation](https://docs.nestjs.com/)
- [React Documentation](https://reactjs.org/docs/getting-started.html)
