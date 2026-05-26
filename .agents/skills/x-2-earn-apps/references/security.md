# Security Considerations for X2Earn Apps

## When to use

Use when the user asks about: anti-farming, bot prevention, security for X2Earn apps, rate limiting rewards, device fingerprinting, reward abuse, suspicious behavior detection, private key management, scaling rewards.

## Overview

X2Earn apps must guard against farmers unfairly obtaining B3TR tokens. Stopping farmers is difficult — the practical goal is to slow their progress until the effort/reward ratio is no longer worth it.

---

## Farming Attack Vectors

| Vector | Description |
|--------|-------------|
| **Single person, single wallet** | Repeats the same claim multiple times. May submit fake images to AI validation |
| **Single person, multiple wallets** | Switches between wallet addresses in VeWorld to repeat claims from different accounts |
| **Bots (scripts)** | Automated scripts submitting claims, possibly generating/adjusting images for AI verification |
| **Coordinated group** | Multiple people collaborating, sharing wallets or social login details, pooling rewards |
| **Exploit vulnerabilities** | Attacks smart contracts or backend APIs directly, bypassing the frontend entirely |

---

## Backend API Security

### Certificate-Based Authentication

Secure endpoints (e.g., `/account`) with signed certificates from VeWorld. The backend validates the certificate and extracts the wallet address to identify the user.

### Captcha Verification

Protect claim endpoints (e.g., `/claim`) with ReCaptcha to ensure requests originate from the frontend, not scripts/bots.

### CORS Domains

Restrict API calls to requests from the same domain. A request from `api.fakeapp.com` to `api.myapp.com` is rejected.

### Rate Limiting

Strategies to limit claim frequency:

- **Time-based cooldown**: No new claim until N hours after the last paid reward. Check via backend database or by reading the last reward event on-chain
- **Round-based limits**: Cap claims per allocation round (week)
- **Device-based limits**: Use device identification to limit claims per device, not just per address

---

## Action Verification

### AI-Based Validation

- Thoroughly test prompts to ensure AI validates as expected
- Test for hallucinations when extracting data from images (e.g., receipts)
- Require a confidence score — flag low-confidence results for manual review

### Unique Identifiers

Every sustainable action needs indisputable evidence: a social media post, external system data, receipt, or timestamp. For AI image verification, prompt the AI to extract data usable as a uniqueness check.

---

## Suspicious Behavior and Banning

Apps should detect patterns like rewards paid every 10 seconds to accounts with no other transaction history. Implement the ability to ban:

- Individual accounts
- Entire devices (not just wallet addresses)

---

## Private Key Management

The distributor account private key must be secure and not visible in network traffic. Backend contracts or APIs signing reward transactions need secure key storage (environment variables, secrets manager, HSM — never hardcoded or client-side).

---

## Device Fingerprinting

Farmers may install VeWorld (or your native app) multiple times on the same device with different wallets — especially on Android where software allows multiple app instances. Mitigations:

- Use tools like **FingerprintJS** to identify devices uniquely
- Ban the device rather than just the account(s)
- For native apps, build protections against multiple installs

---

## Additional Strategies

### Fund Management

The weekly allocation is at risk if the app has vulnerabilities:

- **Withdraw to treasury**: Reduce the app's B3TR balance by moving funds to a treasury account, drip-feeding back as needed
- **Split allocation**: Set a portion for distribution and another as treasury funds (withdrawable anytime)

### Identity Verification

For apps offering social login (Google, Facebook, Twitter):

- Validate social media profiles (complete profile? account age?)
- Consider verification emails
- Flag accounts created very recently

### Progressive Unlocking

New accounts get tighter rate limits and lower rewards. As users demonstrate legitimate usage, they unlock higher limits and rewards. This forces attackers to invest significant effort before reaching meaningful rewards.

### Scaling Rewards by Demand

Dynamically adjust reward amounts based on claim volume:

1. Compute average rewards per second since the start of the week
2. Project forward to end of week
3. If projected spend exceeds the weekly budget, scale down rewards
4. Scale back up during quiet periods

Goal: make the weekly allocation last the full week while guarding against usage spikes (legitimate or bot-driven).

---

## Recommended Service: Guardian

[Guardian](https://docs.guardianstack.ai/) is a fraud detection and risk assessment platform built for the exact challenges X2Earn apps face: bot activity, multi-wallet farming, VPN/proxy abuse, device spoofing, browser tampering, and coordinated fraud.

- Provides detection signals and behavioral risk scoring
- Integrates into frontend or backend flows
- Discount code **VEBETTER50** for 50% off
- Dashboard: `dashboard.guardianstack.ai`
- Docs: `docs.guardianstack.ai`
