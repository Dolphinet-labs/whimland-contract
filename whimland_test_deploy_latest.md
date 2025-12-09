# WhimLand 测试部署文档（最新版 Summary）

本文件根据最新上传的部署文档整理而成，用于记录 WhimLand 项目在测试环境中的最新合约部署地址及部署日志。  
来源文件：WhimLand 测试部署文档 (1).pdf

---

## 1. 竞拍合约（Auction Contract）

### 部署地址
- **proxyAuction:** `0xE7620395ddC7e9335cAd49EAbD62A9367abc5ABd`

### 部署日志
```
== Logs ==
deploy proxyAuction: 0xE7620395ddC7e9335cAd49EAbD62A9367abc5ABd
```

---

## 2. NFT 交易平台（OrderBook + Vault）

### 部署地址
- **WhimLand 资产库 Vault:** `0xCCA403aB874fA1C456E9C5a7159011D687E825b9`
- **WhimLandOrderBook 交易平台:** `0x8fdC85a4887FF7332f43456DeE819667eD35eba6`

### 部署日志
```
== Logs ==
deploy proxyWhimLandVault: 0xCCA403aB874fA1C456E9C5a7159011D687E825b9
deploy proxyWhimLandOrderBook: 0x8fdC85a4887FF7332f43456DeE819667eD35eba6
```

---

## 3. 可编程 NFT（ERC721 - NFTManager）

### 部署地址
- **NftManager（Proxy 合约）:** `0x4246F066439BD6680473E237462630Df9cc1a9FA`

### 部署日志
```
== Logs ==
deploy proxyNftManager: 0x4246F066439BD6680473E237462630Df9cc1a9FA

Minted Master NFT with token ID: 1
Minted #77 Print Editions for Master NFT ID: 1
```

---

# 📌 Summary（最新版本）

| 模块 | 合约 | 地址 |
|------|------|------|
| 竞拍系统 | proxyAuction | `0xE7620395ddC7e9335cAd49EAbD62A9367abc5ABd` |
| NFT 交易平台 Vault | proxyWhimLandVault | `0xCCA403aB874fA1C456E9C5a7159011D687E825b9` |
| NFT 交易平台 OrderBook | proxyWhimLandOrderBook | `0x8fdC85a4887FF7332f43456DeE819667eD35eba6` |
| 可编程 NFT（ERC721） | proxyNftManager | `0x4246F066439BD6680473E237462630Df9cc1a9FA` |

---

# 文档完毕
