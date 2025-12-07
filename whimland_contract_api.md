# whimland 合约接口文档  
## NFTManager 前端接入文档（v1）

合约：**NFTManager（Upgradeable Proxy 部署）**

---

## 核心能力
- 发行 **Master NFT（主 NFT）** 与 **Print Edition（衍生版次）**
- 支持 Print Edition 三种铸造方式：  
  1. 指定编号  
  2. 按顺序批量  
  3. 随机盲盒（VRF 回调）
- 支持 **EIP-2981 版税（royaltyInfo）**
- 支持 **转移限制**：`transferLocked[tokenId]`、`remainingUses[tokenId] > 0`
- 支持 **使用次数核销：useNFT`

⚠️ 此合约为 **Proxy** 架构，初始化由 `initialize()` 执行，不使用逻辑合约构造函数。

---

# 1. 关键概念与状态

## TokenId 与供应量
- `nextTokenId`：下一个将被铸造的 tokenId（默认从 1 开始）
- `maxSupply`：最大供应量（Master + Print）
- `totalMinted = nextTokenId - 1`

## Master 与 Print Edition
- `isMaster[tokenId] == true` → Master NFT
- `fromMaster[printTokenId] = masterId`
- `printEditionNumber[printTokenId] = printNumber`
- `isPrintExist[masterId][printNumber]` → 防重复编号

## 白名单 / 核销权限
- `isWhiteListed[operator][masterId]`
- `isEditer[operator][masterId]`

## 转移限制
- `transferLocked[tokenId]`
- `remainingUses[tokenId] > 0` 才能转移

---

# 2. 初始化与基础查询

## initialize()
```solidity
function initialize(
    string name_,
    string symbol_,
    uint256 maxSupply_,
    string baseURI_,
    address initialOwner_,
    address vrfPod_
) external
```

写入：
- `maxSupply`, `baseURI`, `vrfPod`, `nextTokenId=1`

## 常用 View Getter
- `nextTokenId()`
- `maxSupply()`
- `totalMinted()`
- `metadata(tokenId)`
- `isMaster(tokenId)`
- `fromMaster(tokenId)`
- `printEditionNumber(tokenId)`
- `remainingUses(tokenId)`
- `royaltyInfo(tokenId, salePrice)`

---

# 3. Mint 相关（重点）

---

## 3.1 Mint Master（主 NFT）

### 接口
```solidity
function mintMaster(address to, NFTMetadata md)
    external
    onlyWhiteListed(nextTokenId)
    whenNotPaused
    nonReentrant
    returns (uint256 tokenId);
```

### Metadata 结构
- name  
- description  
- image  
- royaltyBps  
- royaltyReceiver  
- usageLimit  

### 前置条件
- `nextTokenId <= maxSupply`
- 白名单检查：基于即将 mint 的 tokenId

### 执行效果
- `_safeMint`
- `isMaster[tokenId] = true`
- `metadata[tokenId] = md`
- `remainingUses = md.usageLimit`

---

## 3.2 Mint Print（指定 printNumber）

### 接口
```solidity
function mintPrintEdition(address to, uint256 masterId, uint256 printNumber)
```

### 条件
- `isMaster == true`
- `isPrintExist == false`
- 白名单通过

### 执行效果
- `_safeMint`
- 继承 Master metadata
- 记录 printNumber
- `remainingUses = metadata[masterId].usageLimit`

---

## 3.3 批量 Print（按序自动找号）

### 接口
```solidity
function mintBatchPrintEditionByOrder(
    address to,
    uint256 amount,
    uint256 masterId,
    uint256 startingPrintNumber
)
```

机制：
- 自动扫描下一个未占用的编号
- 扫描上限 1000

---

## 3.4 随机盲盒 Mint（VRF）

### 请求接口
```solidity
function mintBatchPrintEditionRandomMasters(
    address to,
    uint256[] calldata masterIds,
    uint256 totalAmount
)
```

事件：
- `MintRequested(requestId, to, totalAmount, masterIds)`

真正 mint 在 VRF 回调中完成。

---

# 4. NFT 使用（useNFT）

## 接口
```solidity
function useNFT(uint256 tokenId)
    public
    nonReentrant
    onlyEditer(tokenId)
    whenNotPaused;
```

条件：
- `remainingUses > 0`
- 调用者必须是 Editor 或 Owner

效果：
- `remainingUses--`

---

# 5. 转移逻辑（Override transfer）

## 限制条件（所有 transferFrom / safeTransferFrom）
- `remainingUses > 0`
- `!transferLocked[tokenId]`

🛑 若 remainingUses == 0 → 不能转移、不能卖出、不能挂单。

---

# 6. Metadata / URI

- `tokenURI` → base64 JSON  
- `tokenURL` → 中心化读取方式：`baseURI + tokenId + ".json"`

---

# 7. 管理员接口（Admin Panel）

- setBaseURI  
- setMaxSupply  
- setRoyaltyInfo  
- setWhiteList  
- setEditer  
- pause / unpause  
- lockTransfer / unlockTransfer  

---

# 8. 前端最常用流程（简表）

## Mint Master
1. `nextTokenId()`
2. owner: `setWhiteList(minter, true, nextTokenId)`
3. user: `mintMaster(to, md)`
4. listen `MintedNFT`

## Mint Print
1. check `isMaster`
2. check `isPrintExist`
3. `mintPrintEdition`
4. listen event

## 批量 Print
- `mintBatchPrintEditionByOrder(to, amount, masterId, 1)`

## VRF 随机
- `mintBatchPrintEditionRandomMasters(...)`

---

# WhimlandOrderBook（订单系统）接口摘要

---

# 1. makeOrders（批量挂单）
```solidity
function makeOrders(LibOrder.Order[] calldata newOrders)
```

检查：
- NFT collection 必须白名单  
- 支付币种必须支持  
- ETH 多退少补

---

# 2. cancelOrders（批量撤单）
```solidity
function cancelOrders(OrderKey[] calldata orderKeys)
```

---

# 3. editOrders（批量改价）
```solidity
function editOrders(LibOrder.EditDetail[] calldata editDetails)
```

只能修改：
- price  
- expiry  
- salt

---

# 4. matchOrder（单笔撮合）
```solidity
function matchOrder(LibOrder.Order sellOrder, LibOrder.Order buyOrder)
```

---

# 5. matchOrders（批量撮合）
```solidity
function matchOrders(LibOrder.MatchDetail[] calldata matchDetails)
```

失败不回滚，逐条记录成功/失败。

---

# Auction 拍卖接口摘要

---

## 1. createAuction
```solidity
function createAuction(...)
```

## 2. placeBid
```solidity
function placeBid(uint256 auctionId, uint256 amount) external payable;
```

## 3. withdraw
提取被超越的出价

## 4. settleAuction
结算拍卖，转移 NFT

## 5. claimNFTForWinner
用于处理结算时 NFT 转账失败时的补领机制

---

# 文档完毕
