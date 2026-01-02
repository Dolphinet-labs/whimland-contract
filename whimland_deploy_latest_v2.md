# WhimLand 测试部署文档（最新版 · 完整重制）

本文档根据**最新上传的《WhimLand 测试部署文档》**重新生成，覆盖 Sepolia / DolPhinnet / DolPhinnet 测试网，
并严格区分 Proxy、Implementation、Oracle、VRF 合约，用于前端、后端与 Cursor 集成。

---

## 一、Sepolia 测试网

### Auction

- Proxy Auction: 0xE7620395ddC7e9335cAd49EAbD62A9367abc5ABd

### NFT 交易平台

- Vault (Proxy): 0xCCA403aB874fA1C456E9C5a7159011D687E825b9
- OrderBook (Proxy): 0x8fdC85a4887FF7332f43456DeE819667eD35eba6

### NFTManager

- Proxy NFTManager: 0x4246F066439BD6680473E237462630Df9cc1a9FA

---

## 二、DolPhinne

### Auction

- Proxy Auction: 0x4246F066439BD6680473E237462630Df9cc1a9FA

### NFT 交易平台

- Vault (Proxy): 0x38Aae48a1236CC9B12dc9eFbcCd95B535CD117A6
- OrderBook (Proxy): 0x0C62111cdb7e245CF62f6B8b0ec2100DB4c39C29

---

## 三、DolPhinnet 测试网（新版）

### Auction

- Proxy Auction: 0x7513088ebC996456D51ec9608144d1777c98E2B2
- Impl Auction: 0x9c9D1Ab1222149E475ec7D19598875Bda0e64A2f

### NFT 交易平台

- Vault (Proxy): 0x961895aC05838BD0f245a619b319d0B61952A7b5
- Vault (Impl): 0xAdD1333587a9d680b7FaAa2F1B88Ed3Ace9c3b82
- OrderBook (Proxy): 0xEA9DA365a233Bc7B8cc93e56cce30488c62F483E
- OrderBook (Impl): 0x455985e353993dBbD9a211ED796976C6D943e649

### NFTManager & VRF

- NFTManager (Proxy): 0x0C62111cdb7e245CF62f6B8b0ec2100DB4c39C29

#### VRF / Oracle（DOL）

- proxyBlsApkRegistry: 0x1d6255a56dF6261184B63082a93ac0d3DDef2b6c
- proxyVrfManager: 0x497b365Ea07d5Bb507c4E668196112B19d317c51
- proxyVrfPod: 0x83da5cfA097E5D62a30de64698929892d38D5C7b
- proxyWhimVrfPod: 0x2ECA23AeE3F5CbF87eaF33857797506c8A6A6d94

---

## 四、DOL 主网（Dolphinet Mainnet - Chain ID: 1520）

### NFTManager

- Proxy NFTManager: 0x332D717949FA0008F6c3538C48394B9d3E2cD69a
- Implementation NFTManager: 0xEE67A397BE3771ab155F02ce2e1F6eaa4b31ea34
- ProxyAdmin: 0x2ea726070ed3677FE9E85d907887757CB5BeA2e6
- EmptyContract: 0x6D60C0B924c1eb2e625318aaE1E96d8682d403e8

**部署信息：**
- 合约名称: Lamei Valley
- 合约符号: LMV
- 最大供应量: 无限制
- Base URI: https://whimlandnft.com/api/v1/nft/LMV/{id}
---