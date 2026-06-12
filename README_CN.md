# 🎨 WhimLand Contract

<div align="center">

**WhimLand 智能合约开源代码库**

WhimLand 是一个基于区块链技术打造的全球泛文娱商品交易平台，专注为全球粉丝与收藏爱好者提供官方授权、正版可溯源的 IP 产品。用户不仅可以在平台上便捷购买与转让数字商品，还可通过授权机制在指定线下场景兑换对应实物，实现数字与实体权益的无缝衔接。

本项目包含 WhimLand 平台的核心智能合约实现，支持订单簿交易、拍卖机制等完整功能。

[![Solidity](https://img.shields.io/badge/Solidity-0.8.23-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-Latest-orange.svg)](https://getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 📋 目录

- [关于 WhimLand](#-关于-whimland)
- [合约功能](#-合约功能)
- [技术架构](#-技术架构)
- [项目结构](#-项目结构)
- [文档入口](#-文档入口)
- [开发指南](#-开发指南)
- [部署（Foundry Scripts）](#-部署foundry-scripts)
- [测试](#-测试)
- [安全考虑](#-安全考虑)
- [贡献](#-贡献)
- [许可证](#-许可证)

---

## 🌟 关于 WhimLand

WhimLand 是一个基于区块链技术打造的全球泛文娱商品交易平台，专注为全球粉丝与收藏爱好者提供官方授权、正版可溯源的 IP 产品。用户不仅可以在平台上便捷购买与转让数字商品，还可通过授权机制在指定线下场景兑换对应实物，实现数字与实体权益的无缝衔接。

本仓库包含 WhimLand 平台的核心智能合约源代码，采用模块化设计，支持订单簿交易、拍卖机制、代币管理等完整功能。

---

## ✨ 合约功能

### 🛒 订单簿系统 (OrderBook)
- **限价订单**：支持买卖双方创建限价订单
- **市价订单**：支持即时成交的市价订单
- **订单匹配**：基于红黑树的高效价格匹配算法
- **订单管理**：订单取消、查询和状态追踪

### 🔨 拍卖系统 (Auction)
- **英式拍卖**：支持 NFT 英式拍卖机制
- **竞价管理**：自动处理最高出价和退款
- **时间控制**：灵活的拍卖时间设置
- **费用管理**：可配置的协议费用

### 💼 代币管理
- **NFT 管理**：统一的 NFT 代币管理接口
- **ERC20 支持**：支持多种 ERC20 代币作为交易货币
- **代币工厂**：可扩展的代币创建机制

### 🔐 安全特性
- **可升级合约**：基于 OpenZeppelin 的可升级代理模式
- **重入保护**：全面的重入攻击防护
- **暂停机制**：紧急情况下的合约暂停功能
- **权限管理**：基于角色的访问控制

---

## 🏗️ 技术架构

### 核心技术栈

- **Solidity**: `^0.8.20` / `^0.8.23`
- **Foundry**: 开发、测试和部署框架
- **OpenZeppelin**: 安全的标准合约库
  - `contracts-upgradeable`: 可升级合约支持
  - `contracts`: 标准 ERC 实现

### 关键组件

```
┌─────────────────────────────────────────┐
│         WhimLandOrderBook               │
│  (订单簿核心合约 - 可升级)              │
├─────────────────────────────────────────┤
│  • OrderStorage (订单存储)              │
│  • OrderValidator (订单验证)            │
│  • ProtocolManager (协议管理)           │
│  • 红黑树价格匹配算法                   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│            NFTAuction                   │
│  (拍卖系统 - 可升级)                    │
├─────────────────────────────────────────┤
│  • 英式拍卖机制                         │
│  • 竞价管理                             │
│  • 自动结算                             │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         WhimLandVault                   │
│  (资金托管合约)                         │
└─────────────────────────────────────────┘
```

---

## 📁 项目结构

```
whimland-contract/
├── src/                          # 合约源代码
│   ├── WhimLandOrderBook.sol    # 订单簿主合约
│   ├── Auction.sol              # 拍卖合约
│   ├── WhimLandVault.sol        # 资金托管合约
│   ├── ProtocolManager.sol      # 协议管理
│   ├── OrderStorage.sol         # 订单存储
│   ├── OrderValidator.sol       # 订单验证
│   ├── TokenFactory.sol         # 代币工厂
│   ├── token/                   # 代币管理
│   │   ├── NFTManager.sol
│   │   └── ERC20Manager.sol
│   ├── libraries/               # 库合约
│   │   ├── LibOrder.sol         # 订单库
│   │   ├── LibPayInfo.sol       # 支付信息库
│   │   ├── RedBlackTreeLibrary.sol  # 红黑树库
│   │   └── LibTransferSafeUpgradeable.sol
│   └── interface/               # 接口定义
│       ├── IWhimLandOrderBook.sol
│       ├── IWhimLandVault.sol
│       └── ...
├── script/                       # 部署脚本
│   ├── deployWhimLand.s.sol
│   ├── deployAuction.s.sol
│   ├── deployNFTManager.s.sol
│   └── utils/
├── test/                         # 测试文件
│   ├── ProtocolManagerTest.sol
│   ├── LibOrderTest.sol
│   └── test/
├── lib/                          # 依赖库
│   ├── forge-std/
│   └── openzeppelin-contracts/
├── broadcast/                    # 部署记录
├── foundry.toml                  # Foundry 配置
└── README.md                     # 项目文档
```

---

## 📚 文档入口

- **合约接口文档（NFTManager / OrderBook / Auction）**：`whimland_contract_api.md`
- **最新部署地址（测试网）**：`whimland_deploy_latest_v2.md`

> 说明：`broadcast/` 目录保存了 Foundry script 的执行记录（按 chain id 归档，包含部署地址与交易信息）。

---

## 🛠️ 开发指南

### 前置要求

- [Foundry](https://getfoundry.sh/) (最新版本)
- Git
- Node.js (用于 JavaScript 测试)

### 安装 Foundry

```bash
# 使用官方安装脚本
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 克隆项目

```bash
git clone <repository-url> --recurse-submodules
cd whimland-contract
```

### 初始化 / 更新子模块

```bash
git submodule update --init --recursive
```

> 本仓库在 `lib/` 下使用了 git submodule（OpenZeppelin、forge-std 等）。如果克隆时没加 `--recurse-submodules`，请先执行上面的命令再 `forge build`。

### 构建项目

```bash
forge build
```

编译后的合约将输出到 `out/` 目录。

### 代码格式化

```bash
forge fmt
```

### Gas 分析

```bash
# 生成 gas 快照
forge snapshot

# 比较 gas 使用情况
forge snapshot --diff

# 显示 gas 报告
forge test --gas-report
```

### 本地开发网络

```bash
# 启动本地 Anvil 节点
anvil

# 在特定端口启动
anvil --port 8545
```

---

## 🚢 部署（Foundry Scripts）

部署脚本位于 `script/`，执行记录会写入 `broadcast/`。

### 常用环境变量

- **RPC**：`DOL_TESTNET_RPC_URL`（示例：Dolphin Node Testnet RPC）
- **部署私钥**：`PRIVATE_KEY_WHIM`

PowerShell 示例：

```powershell
$env:DOL_TESTNET_RPC_URL="https://..."
$env:PRIVATE_KEY_WHIM="0x..."
```

### 部署 WhimLand（Vault + OrderBook proxies）

```bash
forge script script/deployWhimLand.s.sol:DeployerCpChainBridge \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### 部署 Auction（proxy + implementation）

```bash
forge script script/deployAuction.s.sol:DeployerCpChainBridge \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### 部署 NFTManager（proxy + implementation）

```bash
forge script script/deployNFTManager.s.sol:DeployNFTManagerAllinOneMart \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### 部署 WhimLandMarket（需已有 NFTManager 代理地址）

将 `NFT_MANAGER_PROXY` 设为上一布步骤打印的代理地址。

```bash
NFT_MANAGER_PROXY=0x... forge script script/deployWhimLandMarket.s.sol:DeployWhimLandMarket \
  --rpc-url $DOL_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY_WHIM \
  --broadcast --verify \
  --verifier blockscout \
  --verifier-url https://explorer-testnet.dolphinode.world/api/
```

### 为门店商家授予 checker（AllinOne Mart 方案）

1. 编辑 `script/data/aio_checker_master_ids.json`（`masterIds` 为链上 Master 的 tokenId）。
2. 使用 **NFTManager owner** 私钥（`NFT_MANAGER_OWNER_PRIVATE_KEY`，计划中为 `0x2162…`）执行：

```bash
NFT_MANAGER_PROXY=0x... NFT_MANAGER_OWNER_PRIVATE_KEY=0x... \
  forge script script/configureAioMerchantChecker.s.sol:ConfigureAioMerchantChecker \
  --rpc-url $DOL_TESTNET_RPC_URL --broadcast
```

### 升级/更新脚本注意事项

部分脚本内含 **硬编码的 Proxy 地址常量**；如果你要在不同网络执行，需要先修改地址常量：

- `script/updateWhimLandOrderBook.s.sol`（升级 OrderBook implementation）
- `script/upgradeNFTManager.s.sol`（升级 NFTManager implementation）

---

## 🧪 测试

项目包含全面的测试套件，覆盖核心功能：

- ✅ 协议管理测试 (`ProtocolManagerTest.sol`)
- ✅ 订单库测试 (`LibOrderTest.sol`)
- ✅ JavaScript 集成测试 (`test/TestEasySwap.js`)

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试文件
forge test --match-path test/ProtocolManagerTest.sol

# 显示详细输出
forge test -vvv

# 显示 gas 报告
forge test --gas-report

# 运行测试并显示覆盖率
forge coverage
```

---

## 🔒 安全考虑

### 已实施的安全措施

- ✅ **重入保护**: 使用 `ReentrancyGuard` 防止重入攻击
- ✅ **暂停机制**: 紧急情况下可暂停合约操作
- ✅ **权限控制**: 基于 OpenZeppelin 的 `Ownable` 权限管理
- ✅ **安全转账**: 使用 `SafeERC20` 和自定义安全转账库
- ✅ **输入验证**: 全面的参数验证和边界检查
- ✅ **可升级性**: 使用透明代理模式，支持安全升级

### 安全审计建议

⚠️ **重要**: 在生产环境部署前，建议进行专业的安全审计。

### 最佳实践

1. 始终在主网部署前在测试网充分测试
2. 使用多签钱包管理合约所有权
3. 定期审查和更新依赖库
4. 监控合约事件和异常行为
5. 实施紧急响应计划

---

## 🤝 贡献

我们欢迎社区贡献！请遵循以下步骤：

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 开发规范

- 遵循 Solidity 风格指南
- 为新功能添加测试
- 更新相关文档
- 确保所有测试通过

---

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

---

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [Issue](../../issues)
- 创建 [Pull Request](../../pulls)

---

## 🙏 致谢

- [OpenZeppelin](https://openzeppelin.com/) - 提供安全的标准合约库
- [Foundry](https://getfoundry.sh/) - 强大的开发工具链
- 所有贡献者和社区支持者

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给我们一个 Star！**

Made with ❤️ by WhimLand Team

</div>
