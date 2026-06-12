# 🎨 WhimLand Contract

<div align="center">

**WhimLand Smart Contract Open Source Repository**

WhimLand is a global entertainment goods trading platform built on blockchain technology, dedicated to providing officially authorized, authentic, and traceable IP products for fans and collectors worldwide. Users can not only conveniently purchase and transfer digital goods on the platform, but also exchange corresponding physical items in designated offline scenarios through an authorization mechanism, achieving seamless integration of digital and physical rights.

This repository contains the core smart contract implementation of the WhimLand platform, supporting order book trading, auction mechanisms, and other complete features.

[![Solidity](https://img.shields.io/badge/Solidity-0.8.23-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-orange.svg)](https://getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 📋 Table of Contents

- [About WhimLand](#-about-whimland)
- [Contract Features](#-contract-features)
- [Technical Architecture](#-technical-architecture)
- [Project Structure](#-project-structure)
- [Docs](#-docs)
- [Getting Started](#-getting-started)
- [Deployment (Foundry Scripts)](#-deployment-foundry-scripts)
- [Testing](#-testing)
- [Security Considerations](#-security-considerations)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🌟 About WhimLand

WhimLand is a global entertainment goods trading platform built on blockchain technology, dedicated to providing officially authorized, authentic, and traceable IP products for fans and collectors worldwide. Users can not only conveniently purchase and transfer digital goods on the platform, but also exchange corresponding physical items in designated offline scenarios through an authorization mechanism, achieving seamless integration of digital and physical rights.

This repository contains the core smart contract source code of the WhimLand platform, featuring a modular design that supports order book trading, auction mechanisms, token management, and other complete functionalities.

---

## ✨ Contract Features

### 🛒 Order Book System (OrderBook)
- **Limit Orders**: Support for creating limit orders by both buyers and sellers
- **Market Orders**: Support for instant execution market orders
- **Order Matching**: Efficient price matching algorithm based on Red-Black Tree
- **Order Management**: Order cancellation, querying, and status tracking

### 🔨 Auction System (Auction)
- **English Auction**: Support for NFT English auction mechanism
- **Bid Management**: Automatic handling of highest bids and refunds
- **Time Control**: Flexible auction time settings
- **Fee Management**: Configurable protocol fees

### 💼 Token Management
- **NFT Management**: Unified NFT token management interface
- **ERC20 Support**: Support for multiple ERC20 tokens as trading currencies
- **Token Factory**: Extensible token creation mechanism

### 🔐 Security Features
- **Upgradeable Contracts**: Based on OpenZeppelin's upgradeable proxy pattern
- **Reentrancy Protection**: Comprehensive protection against reentrancy attacks
- **Pause Mechanism**: Contract pause functionality for emergency situations
- **Access Control**: Role-based access control

---

## 🏗️ Technical Architecture

### Core Technology Stack

- **Solidity**: `^0.8.20` / `^0.8.23`
- **Foundry**: Development, testing, and deployment framework
- **OpenZeppelin**: Secure standard contract library
  - `contracts-upgradeable`: Upgradeable contract support
  - `contracts`: Standard ERC implementations

### Key Components

```
┌─────────────────────────────────────────┐
│         WhimLandOrderBook               │
│  (Order Book Core Contract - Upgradeable)│
├─────────────────────────────────────────┤
│  • OrderStorage (Order Storage)         │
│  • OrderValidator (Order Validation)    │
│  • ProtocolManager (Protocol Management)│
│  • Red-Black Tree Price Matching        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│            NFTAuction                   │
│  (Auction System - Upgradeable)         │
├─────────────────────────────────────────┤
│  • English Auction Mechanism            │
│  • Bid Management                       │
│  • Automatic Settlement                 │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         WhimLandVault                   │
│  (Fund Custody Contract)                 │
└─────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
whimland-contract/
├── src/                          # Contract source code
│   ├── WhimLandOrderBook.sol    # Order book main contract
│   ├── Auction.sol              # Auction contract
│   ├── WhimLandVault.sol        # Fund custody contract
│   ├── ProtocolManager.sol      # Protocol management
│   ├── OrderStorage.sol         # Order storage
│   ├── OrderValidator.sol       # Order validation
│   ├── TokenFactory.sol         # Token factory
│   ├── token/                   # Token management
│   │   ├── NFTManager.sol
│   │   └── ERC20Manager.sol
│   ├── libraries/               # Library contracts
│   │   ├── LibOrder.sol         # Order library
│   │   ├── LibPayInfo.sol       # Payment info library
│   │   ├── RedBlackTreeLibrary.sol  # Red-Black Tree library
│   │   └── LibTransferSafeUpgradeable.sol
│   └── interface/               # Interface definitions
│       ├── IWhimLandOrderBook.sol
│       ├── IWhimLandVault.sol
│       └── ...
├── script/                       # Deployment scripts
│   ├── deployWhimLand.s.sol
│   ├── deployAuction.s.sol
│   ├── deployNFTManager.s.sol
│   └── utils/
├── test/                         # Test files
│   ├── ProtocolManagerTest.sol
│   ├── LibOrderTest.sol
│   └── test/
├── lib/                          # Dependencies
│   ├── forge-std/
│   └── openzeppelin-contracts/
├── broadcast/                    # Deployment records
├── foundry.toml                  # Foundry configuration
└── README.md                     # Project documentation
```

---

## 📚 Docs

- **Contract API (NFTManager / OrderBook / Auction)**: `whimland_contract_api.md`
- **Latest deployment addresses (testnets)**: `whimland_deploy_latest_v2.md`

> Note: The `broadcast/` directory contains Foundry script execution records (including deployed addresses per chain id).

---

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- Git
- Node.js (for JavaScript tests)

### Installation

1. **Install Foundry**

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. **Clone the repository**

```bash
git clone <repository-url> --recurse-submodules
cd whimland-contract
```

3. **Init / update submodules**

```bash
git submodule update --init --recursive
```

> This repository uses git submodules under `lib/` (OpenZeppelin, forge-std, etc.). If you cloned without `--recurse-submodules`, run the command above before `forge build`.

### Building

```bash
forge build
```

Compiled contracts will be output to the `out/` directory.

### Code Formatting

```bash
forge fmt
```

### Local Development

Start a local Anvil node for development:

```bash
anvil
```

---

## 🚢 Deployment (Foundry Scripts)

Deployment scripts live in `script/` and write execution records to `broadcast/`.

### Common environment variables

- **RPC**: `DOL_TESTNET_RPC_URL` (example: Dolphin Node Testnet RPC)
- **Deployer key**: `PRIVATE_KEY_WHIM`

PowerShell example:

```powershell
$env:DOL_TESTNET_RPC_URL="https://..."
$env:PRIVATE_KEY_WHIM="0x..."
```

### Deploy WhimLand (Vault + OrderBook proxies)

```bash
forge script script/deployWhimLand.s.sol:DeployerCpChainBridge \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### Deploy Auction (proxy + implementation)

```bash
forge script script/deployAuction.s.sol:DeployerCpChainBridge \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### Deploy NFTManager (proxy + implementation)

```bash
forge script script/deployNFTManager.s.sol:DeployNFTManagerAllinOneMart \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### Deploy WhimLandMarket (after NFTManager proxy exists)

Set `NFT_MANAGER_PROXY` to the proxy address printed by the step above.

```bash
NFT_MANAGER_PROXY=0x... forge script script/deployWhimLandMarket.s.sol:DeployWhimLandMarket \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### Grant merchant checker (AllinOne Mart plan)

1. Edit `script/data/aio_checker_master_ids.json` (`masterIds` = on-chain master token IDs).
2. Run with the **NFTManager owner** key (`NFT_MANAGER_OWNER_PRIVATE_KEY`, i.e. `0x2162…`).

```bash
NFT_MANAGER_PROXY=0x... NFT_MANAGER_OWNER_PRIVATE_KEY=0x... \
  forge script script/configureAioMerchantChecker.s.sol:ConfigureAioMerchantChecker \
  --rpc-url $DOL_TESTNET_RPC_URL --broadcast
```

### Upgrade / update scripts

Some scripts contain **hardcoded proxy addresses** (constants). Before running them on a different network, update the address constants:

- `script/updateWhimLandOrderBook.s.sol` (upgrades OrderBook implementation)
- `script/upgradeNFTManager.s.sol` (upgrades NFTManager implementation)

---

## 🧪 Testing

The project includes comprehensive test suites covering core functionality:

- ✅ Protocol management tests (`ProtocolManagerTest.sol`)
- ✅ Order library tests (`LibOrderTest.sol`)
- ✅ JavaScript integration tests (`test/TestEasySwap.js`)

### Running Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/ProtocolManagerTest.sol

# Show verbose output
forge test -vvv

# Show gas report
forge test --gas-report

# Run tests with coverage
forge coverage
```

---

## 🔒 Security Considerations

### Implemented Security Measures

- ✅ **Reentrancy Protection**: Using `ReentrancyGuard` to prevent reentrancy attacks
- ✅ **Pause Mechanism**: Ability to pause contract operations in emergencies
- ✅ **Access Control**: Role-based access control using OpenZeppelin's `Ownable`
- ✅ **Safe Transfers**: Using `SafeERC20` and custom safe transfer libraries
- ✅ **Input Validation**: Comprehensive parameter validation and boundary checks
- ✅ **Upgradeability**: Using transparent proxy pattern for secure upgrades

### Security Audit Recommendations

⚠️ **Important**: Professional security audits are recommended before deploying to production.

### Best Practices

1. Always thoroughly test on testnets before mainnet deployment
2. Use multi-signature wallets to manage contract ownership
3. Regularly review and update dependencies
4. Monitor contract events and anomalous behavior
5. Implement emergency response plans

---

## 🤝 Contributing

We welcome community contributions! Please follow these steps:

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guidelines
- Add tests for new features
- Update relevant documentation
- Ensure all tests pass

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 📞 Contact

For questions or suggestions, please contact us through:

- Submit an [Issue](../../issues)
- Create a [Pull Request](../../pulls)

---

## 🙏 Acknowledgments

- [OpenZeppelin](https://openzeppelin.com/) - Providing secure standard contract libraries
- [Foundry](https://getfoundry.sh/) - Powerful development toolchain
- All contributors and community supporters

---

<div align="center">

**⭐ If this project helps you, please give us a Star!**

Made with ❤️ by WhimLand Team

</div>

