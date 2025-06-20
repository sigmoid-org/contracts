# Sigmoid

![image](https://github.com/user-attachments/assets/29469c1d-0573-4746-8442-c03d598a8e9c)

Welcome to **Sigmoid** — the decentralized platform where creators turn their work into shareable assets, fans become stakeholders, and royalties flow transparently and automatically. Whether you’re a musician, filmmaker, writer, or artist, Sigmoid enables you to tokenize your creative projects and build a community-powered economy around them. 
For Full Docmentation: https://sigmoid-2.gitbook.io/sigmoid

---
![image](https://github.com/user-attachments/assets/45f97591-ddc9-4ec1-abdb-4bf111839ba8)


## Use Case Example: MrBeast's Tokenized Video

Imagine MrBeast launches a viral *Willy Wonka’s Chocolate Factory* video. Instead of only relying on ad revenue, he tokenizes the video by creating **1,000 ownership shares**:

* Keeps **600 shares** for himself
* Offers **400 shares** to fans at **\$1 per share**

As royalties roll in (from YouTube ads, Spotify streams, licensing deals, etc.), shareholders get paid — automatically, transparently, and directly to their wallets.

This is the future of creative monetization.

---
![image](https://github.com/user-attachments/assets/1ad96851-22f5-4831-8656-d2dd17d643e5)
![image](https://github.com/user-attachments/assets/e154a017-9160-49b8-b26b-fa000efa482b)


## Who This Is For

<img width="880" alt="image" src="https://github.com/user-attachments/assets/bb89b550-3589-40ef-9bcc-dba1c1b038e5" />


**Creators**
Artists, musicians, filmmakers, writers — anyone who wants to tokenize their work and create new revenue streams with their fans.

**Investors**
Fans, collectors, and supporters who want to buy into creative projects and earn royalties alongside their favorite creators.

**Developers**
Builders and hackers looking to integrate with our smart contracts, build dApps, or extend the platform in new directions.

**Businesses**
Agencies, labels, and rights-holders curious about how Web3 tokenization can unlock new monetization models.

---

## Platform Highlights

* **Multi-Asset Support:** Music, art, poetry, video, code, and more
* **Story Protocol Integration:** Professional IP management and licensing
* **Fractional Ownership:** Share-based ownership model
* **Automatic Royalty Distribution:** Fair and transparent revenue sharing
* **Portfolio Management:** Real-time tracking and earnings monitoring

---

## Portfolio Management

Track your investments and returns with powerful on-chain insights.

```js
// Get all your asset shares
const myShares = await contract.getAllAssetShares();

// Check specific asset shares
const shares = await contract.getUserShares(yourAddress, assetId);
```
![image](https://github.com/user-attachments/assets/4fc31633-1a19-4373-b7ed-203bd3b9882a) ![image](https://github.com/user-attachments/assets/dd9662f6-b1d6-40ff-b667-dc013dd822dd)


**Key Metrics:**

* Total Investment
* Current Valuation
* Total Royalty Earnings
* Return on Investment (ROI)

---

## Diversification Strategy

**Recommended Allocation:**

* 60% - Established creators (lower risk)
* 30% - Growth opportunities (medium risk)
* 10% - Experimental or high-risk assets

**Asset Diversification:**

* Spread across asset types (music, video, art)
* Mix of mainstream and niche categories
* Balance short-term trends with long-term value

---
![image](https://github.com/user-attachments/assets/783347f5-3492-4848-8fc5-da4cad35f0c9) ![image](https://github.com/user-attachments/assets/ca98aac5-539f-4ccf-9819-b3aaad8cc018)


## Tomo Wallet Integration

We integrated **[Tomo Wallet](https://tomo.inc/)** to provide a seamless and secure web3 login and transaction experience for our users. This integration allowed us to support multiple EVM chains effortlessly, including Ethereum, Polygon, Arbitrum, Optimism, Base, and more.

### How We Used Tomo Wallet

* We used the `@tomo-inc/tomo-evm-kit` library to add wallet login and EVM chain support to our frontend.

* With the help of **TomoEVMKitProvider**, we wrapped our app to initialize the wallet context:

  ```tsx
  import { TomoEVMKitProvider, getDefaultConfig } from '@tomo-inc/tomo-evm-kit';
  import { WagmiProvider } from 'wagmi';

  const config = getDefaultConfig({
    appName: 'YourApp',
    projectId: '<your-walletconnect-project-id>',
    chains: [mainnet, polygon, arbitrum, optimism, base],
  });

  <WagmiProvider config={config}>
    <TomoEVMKitProvider>
      {/* your app components */}
    </TomoEVMKitProvider>
  </WagmiProvider>
  ```

* We added support for **social logins** (Google, Apple, Twitter, etc.) using Tomo’s prebuilt authentication UI.

* Tomo handled user wallet creation, signing, and message verification under the hood with a simplified UX.

### How It Helped Us

* **Easy Onboarding**: Users could log in with just a Google or Apple account — no need to install browser extensions or manage seed phrases.
* **Multi-chain Support**: Enabled smooth interactions across different EVM-compatible chains.
* **Gasless UX** (optional): Tomo supports abstracted transactions with paymaster integrations.
* **Time-Saving**: Reduced integration time drastically compared to building a custom wallet auth system.
* **Security**: Authenticated and encrypted key management via Tomo's secure backend.

### Screenshots

#### Tomo Wallet login interface:

<img width="465" alt="image" src="https://github.com/user-attachments/assets/071a76f1-cbee-43e1-9302-c21aec38e3b2" />

#### Logged-in dashboard with active wallet:

<img width="1470" alt="image" src="https://github.com/user-attachments/assets/892b8664-96d7-4acb-8875-7449b532f130" />

---


## Earning and Claiming Royalties

**How It Works:**

1. Revenue is generated from external platforms (YouTube, Spotify, licensing)
2. Creator deposits royalties into the smart contract
3. Snapshot of shareholders is taken
4. Each holder claims their share

**Claiming Example:**

```js
// Get distributions
const distributions = await contract.getAllDistributions(assetId);

// Claim from the latest distribution
const tx = await contract.claimRoyalties(assetId, 0);
await tx.wait();
```

---

## Maximizing Returns

**Active Strategies:**

* Vote on asset verification
* Invest early in promising assets
* Engage with creators and communities

**Passive Strategies:**

* Buy and hold
* Diversify
* Reinvest royalties

---

## Understanding and Managing Risk

**Types of Risk:**

* **Market Risk:** Creator popularity and asset value may fluctuate
* **Technical Risk:** Smart contract bugs, blockchain issues
* **Liquidity Risk:** Currently no secondary share market

**Risk Mitigation Tips:**

* Diversify across creators and asset types
* Start with small investments
* Research creator history and community engagement
* Stay updated with platform news

---

## Smart Contract Architecture

### 1. Main Platform Contract

**Role:** Central orchestrator

**Functions:**

* User registration and profiles
* Asset creation and tokenization
* Royalty distribution coordination
* Access control and permissions
* Relationship mapping across modules

---

### 2. Asset NFT Contract

**Role:** ERC-721 token for each unique asset

**Features:**

* Minted via main platform
* Stores immutable metadata
* Links to IPFS or Story Protocol registry

```solidity
contract AssetNFT is ERC721, ERC721URIStorage, Ownable {
    // Controlled minting by platform only
}
```

---

### 3. Asset Share Token Contracts

**Role:** ERC-20 fractional ownership

**Features:**

* Separate contract per asset
* Price per share, max supply
* Linked to the asset creator

```solidity
contract AssetShareToken is ERC20, Ownable {
    uint256 public pricePerShare;
    uint256 public maxSupply;
    address public assetCreator;
}
```

---

### 4. Story Protocol Integration

**Modules Integrated:**

* IP Asset Registry
* Licensing Module
* PIL Templates
* Royalty Policies

Enables professional-grade licensing, IP validation, and programmable royalty terms.

---

## Data Architecture

**On-Chain:**

* User profiles
* Asset metadata and ownership
* Share balances and royalty history
* Verification records

```solidity
mapping(uint256 => Asset) public assets;
mapping(address => CreatorProfile) public creators;
```

**Off-Chain:**

* IPFS for media (images, audio, video)
* Metadata JSON
* Analytics, preferences, and cached data (optional)

---

## Security and Economic Design

**Access Control:**

```solidity
modifier onlyOwner() { ... }
modifier onlyCreator(uint256 assetId) { ... }
modifier assetExists(uint256 assetId) { ... }
```

**Security Patterns:**

* Reentrancy protection using `ReentrancyGuard`
* Input validation and overflow protection
* Smart contract audits and upgradability checks

**Fees & Incentives:**

* 5% fee on royalty deposits
* Creators must retain 10–90% of shares to maintain incentive alignment





## Contributing

We're building Sigmoid for creators and the community. If you’re a developer, auditor, or designer — we’d love to collaborate.

* Clone this repo
* Review our smart contracts
* Submit pull requests or issues

---

## License

MIT License. See `LICENSE` for details.

---

## Contact

For partnerships, integrations, or support:

* Email: [hello@sigmoid.xyz](mailto:sigmoid.hello@gmail.com)
* Twitter: [@SigmoidPlatform](https://x.com/sigmoid423182)
* Website: [https://sigmoid.xyz](https://sigmoid-story.vercel.app/)

