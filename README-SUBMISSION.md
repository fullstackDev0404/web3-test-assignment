# ChainQuest - Web3 Engineer Home Task Submission

## Candidate Information

- **Name**: [YOUR NAME]
- **Email**: [YOUR EMAIL]

## Contract Address

- **QuestEscrow Address**: [DEPLOYED CONTRACT ADDRESS - run `npm run contracts:deploy` to get this]

## How to Run

### Prerequisites
- Node.js installed
- MetaMask or compatible Web3 wallet

### Setup

```bash
# Install dependencies
npm install
npm install --prefix contracts
```

### Part A - Run Contract Tests

```bash
cd contracts
npx hardhat test test/QuestEscrow.assessment.test.ts
```

All 9 scenarios (A-I) should pass.

### Part B - Deploy Contracts & Run UI

**Terminal 1** - Start local blockchain:
```bash
npm run contracts:node
```

**Terminal 2** - Deploy contracts:
```bash
npm run contracts:deploy
```
Copy the deployed addresses to `.env.local` (see `.env.example` for format).

**Terminal 3** - Start the frontend:
```bash
npm run dev
```

Open http://localhost:3000

### MetaMask Setup

1. Add custom network:
   - Chain ID: 31337
   - RPC URL: http://127.0.0.1:8545

2. Import Hardhat accounts (use private keys from the node terminal)

### Part C - UI Flow

1. Connect wallet in header
2. Create quest on `/quests/create`
3. View quest on `/quests` (Open status)
4. Switch to second account, accept quest on `/quests/[id]`
5. Submit deliverable
6. Switch back to first account, approve & pay → Completed
7. Verify worker balance ≈ 97% of reward

## GitHub Repository

[YOUR GITHUB REPO URL]

## Screenshots

Screenshots of the UI flow are available in the `assets/` directory.
