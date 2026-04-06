# Deploy to Base

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- A wallet with Base Sepolia ETH (get from [Coinbase faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet))
- A [Basescan](https://basescan.org) API key for contract verification

## 1. Configure environment

```bash
cd contracts
cp .env.example .env
```

Edit `.env`:

```
DEPLOYER_PRIVATE_KEY=0x...your_key...
FEE_RECIPIENT=0x...address_for_protocol_fees...
ARBITRATOR=0x...address_of_arbitrator...
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASESCAN_API_KEY=...your_basescan_api_key...
```

## 2. Deploy

```bash
source .env
forge script script/Deploy.s.sol \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

The script outputs addresses like:

```
=== Deployment Summary ===
StakingVault:    0x1234...
AgentRegistry:   0x2345...
ReputationSystem: 0x3456...
Escrow:          0x4567...
DisputeResolver: 0x5678...
JobRegistry:     0x6789...
==========================
```

## 3. Update SDK and API

Copy the addresses to:
- `sdk/src/types.ts` — update `BASE_SEPOLIA_ADDRESSES`
- `api/.env` — set the `*_ADDRESS` variables
- `dashboard/.env.local` — set the `NEXT_PUBLIC_*_ADDRESS` variables

## 4. Start the API

```bash
cd api
cp .env.example .env
# set DATABASE_URL and contract addresses
npm run db:push
npm run dev
```

## 5. Start the Dashboard

```bash
cd dashboard
cp .env.local.example .env.local
# set contract addresses and WalletConnect project ID
npm run dev
```

## Mainnet Deployment

For Base mainnet, use `--rpc-url base_mainnet` and adjust gas price:

```bash
forge script script/Deploy.s.sol \
  --rpc-url base_mainnet \
  --broadcast \
  --verify \
  --gas-price 100000000
```

:::warning
Audit the contracts before mainnet deployment. The staking and escrow contracts hold real ETH.
:::
