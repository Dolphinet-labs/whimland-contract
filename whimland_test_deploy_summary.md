# WhimLand 测试部署文档（Summary）

本文件总结了 WhimLand 项目的三大核心模块在测试环境中的部署地址及部署日志。

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
- **WhimLand 资产库 Vault:** `0x38Aae48a1236CC9B12dc9eFbcCd95B535CD117A6`
- **WhimLandOrderBook 交易平台:** `0x0C62111cdb7e245CF62f6B8b0ec2100DB4c39C29`

### 部署日志
```
== Logs ==
deploy proxyWhimLandVault: 0x38Aae48a1236CC9B12dc9eFbcCd95B535CD117A6
deploy proxyWhimLandOrderBook: 0x0C62111cdb7e245CF62f6B8b0ec2100DB4c39C29
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

# 📌 Summary

| 模块 | 合约 | 地址 |
|------|------|------|
| 竞拍系统 | proxyAuction | `0xE7620395ddC7e9335cAd49EAbD62A9367abc5ABd` |
| NFT 交易平台 Vault | proxyWhimLandVault | `0x38Aae48a1236CC9B12dc9eFbcCd95B535CD117A6` |
| NFT 交易平台 OrderBook | proxyWhimLandOrderBook | `0x0C62111cdb7e245CF62f6B8b0ec2100DB4c39C29` |
| 可编程 NFT（ERC721） | proxyNftManager | `0x4246F066439BD6680473E237462630Df9cc1a9FA` |

---

# 文档完毕
