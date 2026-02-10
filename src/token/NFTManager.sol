// 可编程NFT合约
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";

import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "../interface/IVrfPod.sol";

contract NFTManager is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable
{
    using Strings for uint256;
    using SafeERC20 for IERC20;

    // ============== Storage =====================
    uint256 public nextTokenId;
    uint256 public maxSupply; // 最大供应量
    string public baseURI; // 基础URI
    address public editer;
    uint256 public nextRequestId;
    uint256 public reservedSupply; // Track reserved but not yet minted tokens

    // Master/Print edition
    mapping(uint256 => bool) public isMaster;
    mapping(uint256 => uint256) public printEditionNumber; // Print edition 编号
    mapping(uint256 => uint256) public remainingUses; // 剩余核销次数
    mapping(uint256 => mapping(uint256 => bool)) public isPrintExist; // masterId => printNumber => exists, 用于防止重复铸造print edition
    mapping(uint256 => uint256) public fromMaster; // Print edition 来源的 Master ID
    mapping(address => bool) public isWhiteListed; // 白名单地址---允许铸造权限
    mapping(address => mapping(uint256 => bool)) public isEditer; // 核销权限地址
    mapping(address => mapping(uint256 => bool)) public isChecker; // 核销权限地址

    // Metadata
    struct NFTMetadata {
        string name;
        string description;
        string metadataURL; // 元数据URL
        uint96 royaltyBps; // 版税，单位 BP（500 = 5%）
        address royaltyReceiver; // 版税收款地址
        uint256 usageLimit; // 可使用次数
    }
    mapping(uint256 => NFTMetadata) public metadata;

    // 转移控制
    mapping(uint256 => bool) public transferLocked;

    // 盲盒请求信息
    struct RequestInfo {
        address receiver;
        uint256 totalAmount;
        uint256[] masterIds;
        bool fulfilled;
    }
    mapping(uint256 => RequestInfo) public requests;
    IVrfPod public vrfPod;

    uint256 public pendingHead;
    uint256 public pendingTail;
    mapping(uint256 => uint256) internal queue;

    // ============== New Storage for Master Edition Sales =====================
    struct MasterSale {
        uint256 price;
        address paymentToken; // address(0) for Native ETH
        bool isForSale;
    }
    mapping(uint256 => MasterSale) public masterSales;

    uint256 public platformFeeBps; // 平台手续费，单位 BP（例如 250 = 2.5%）
    address public feeReceiver; // 手续费接收地址

    // ============== New Storage for Blind Box =====================
    struct BlindBoxCampaign {
        uint256[] masterIds; // 候选 Master ID 列表
        uint256 mintPerDraw; // 每次抽盲盒 mint 的数量
        uint256 price; // 每次抽盲盒的价格
        address paymentToken; // 付款代币地址 (address(0) 表示 ETH)
        address creator; // 盲盒活动创建者
        uint256 expireAt; // 过期时间戳，0 表示不自动过期
        bool isActive; // 是否激活中
    }
    uint256 public nextBlindBoxId;
    mapping(uint256 => BlindBoxCampaign) public blindBoxCampaigns;

    // ============== Events =====================
    event FeeConfigUpdated(uint256 feeBps, address feeReceiver);
    event MasterEditionListed(
        uint256 indexed masterId,
        uint256 price,
        address paymentToken
    );
    event MasterEditionUnlisted(uint256 indexed masterId);
    event PrintEditionPurchased(
        uint256 indexed masterId,
        uint256 tokenId,
        address buyer,
        uint256 price
    );
    event BlindBoxCreated(
        uint256 indexed blindBoxId,
        address creator,
        uint256[] masterIds,
        uint256 mintPerDraw,
        uint256 price,
        address paymentToken,
        uint256 expireAt
    );
    event BlindBoxRedeemed(
        uint256 indexed blindBoxId,
        address buyer,
        uint256[] tokenIds,
        uint256[] chosenMasterIds
    );
    event BlindBoxCancelled(uint256 indexed blindBoxId);

    event Received(address indexed sender, uint256 amount);
    event MintedNFT(
        address indexed to,
        uint256 tokenId,
        uint256 masterId,
        uint256 printNumber,
        uint256 usageLimit
    );
    event NFTUsed(uint256 tokenID, uint256 remainingUses, uint256 timestamp);
    event MintRequested(
        uint256 requestId,
        address indexed to,
        uint256 totalAmount,
        uint256[] masterIds
    );
    event MintCompleted(uint256 requestId, uint256[] chosenMasterIds);

    // ============== Modifiers =====================
    modifier onlyWhiteListed() {
        require(
            isWhiteListed[msg.sender] || msg.sender == owner(),
            "Not whitelisted"
        );
        _;
    }

    modifier onlyEditer(uint256 tokenId) {
        _onlyEditer(tokenId);
        _;
    }

    function _enqueue(uint256 id) internal {
        queue[pendingTail++] = id;
    }

    function _dequeue() internal returns (uint256) {
        require(pendingHead < pendingTail, "No pending requests");
        return queue[pendingHead++];
    }

    function _onlyEditer(uint256 tokenId) internal view {
        uint256 _masterId = fromMaster[tokenId];
        require(
            isEditer[msg.sender][_masterId] || msg.sender == owner(),
            "No Access to eidt"
        );
    }

    function getTokenIdTraits(
        uint256 tokenId
    )
        external
        view
        returns (bool master, uint256 masterId, uint256 printNumber)
    {
        _requireOwned(tokenId);
        master = isMaster[tokenId];
        masterId = fromMaster[tokenId];
        printNumber = printEditionNumber[tokenId];
        return (master, masterId, printNumber);
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        string memory baseURI_,
        address _initialOwner,
        address _vrfPod
    ) public initializer {
        maxSupply = maxSupply_;
        baseURI = baseURI_;
        __ERC721_init(name_, symbol_);

        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);
        _transferOwnership(_initialOwner);
        __Pausable_init();
        vrfPod = IVrfPod(_vrfPod);
        nextTokenId = 1;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // // ===================== Normal Mint =====================
    // function mint(address to) public onlyWhiteListed whenNotPaused {
    //     require(nextTokenId <= maxSupply, "Exceeds max supply");
    //     _safeMint(to, nextTokenId);
    //     nextTokenId++;
    // }

    // function mintBatch(
    //     address to,
    //     uint256 amount
    // ) public onlyWhiteListed whenNotPaused {
    //     require(nextTokenId + amount - 1 <= maxSupply, "Exceeds max supply");
    //     for (uint256 i = 0; i < amount; i++) {
    //         _safeMint(to, nextTokenId);
    //         nextTokenId++;
    //     }
    // }

    // ======================= Mint Master & Print Edition =====================

    function mintMaster(
        address to,
        NFTMetadata memory md
    ) external onlyWhiteListed whenNotPaused nonReentrant returns (uint256) {
        require(md.royaltyReceiver != address(0), "Invalid royalty receiver");
        require(nextTokenId <= maxSupply, "Exceeds max supply");
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        isMaster[tokenId] = true;
        fromMaster[tokenId] = tokenId; // Master 的 fromMaster 指向自己

        metadata[tokenId] = md;

        remainingUses[tokenId] = md.usageLimit; // 初始化剩余使用次数

        isEditer[msg.sender][tokenId] = true; // Mint 时默认给铸造者核销权限与print edition铸造权限

        emit MintedNFT(to, tokenId, tokenId, 0, md.usageLimit);
        return tokenId;
    }

    function mintPrintEdition(
        address to,
        uint256 masterId,
        uint256 printNumber,
        string memory metadataURL
    )
        external
        onlyWhiteListed
        onlyEditer(masterId)
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(nextTokenId <= maxSupply, "Exceeds max supply");
        require(isMaster[masterId], "Invalid masterId");
        require(
            !isPrintExist[masterId][printNumber],
            "Print number already exists"
        );

        uint256 tokenId = nextTokenId++;

        _safeMint(to, tokenId);

        // 标记为非 Master
        isMaster[tokenId] = false;
        fromMaster[tokenId] = masterId;

        // 设置 Print edition 编号
        printEditionNumber[tokenId] = printNumber;

        // 继承 Master 的 metadata
        // metadata[tokenId] = metadata[masterId];
        NFTMetadata memory metadataTem = metadata[masterId];
        metadataTem.metadataURL = metadataURL;
        metadata[tokenId] = metadataTem;

        isPrintExist[masterId][printNumber] = true;

        remainingUses[tokenId] = metadata[masterId].usageLimit;

        emit MintedNFT(
            to,
            tokenId,
            masterId,
            printNumber,
            metadata[tokenId].usageLimit
        );
        return tokenId;
    }

    function mintBatchPrintEditionByOrder(
        address to,
        uint256 amount,
        uint256 masterId,
        uint256 startingPrintNumber,
        string[] memory metadataURLs
    ) external onlyWhiteListed onlyEditer(masterId) whenNotPaused nonReentrant {
        require(nextTokenId + amount - 1 <= maxSupply, "Exceeds max supply");
        require(isMaster[masterId], "Invalid masterId");
        require(metadataURLs.length == amount, "Metadata URLs length mismatch");
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = nextTokenId++;

            _safeMint(to, tokenId);
            // 标记为非 Master
            isMaster[tokenId] = false;
            fromMaster[tokenId] = masterId;

            uint256 attempts;
            uint256 MAX_SCAN = 1000; // 可配置

            // Print edition 编号从 startingPrintNumber 开始
            while (isPrintExist[masterId][startingPrintNumber]) {
                unchecked {
                    startingPrintNumber++;
                    attempts++;
                }
                require(attempts < MAX_SCAN, "Print number scan limit reached");
            }

            printEditionNumber[tokenId] = startingPrintNumber;
            isPrintExist[masterId][startingPrintNumber] = true;

            // 继承 Master 的 metadata
            NFTMetadata memory metadataTem = metadata[masterId];
            remainingUses[tokenId] = metadataTem.usageLimit;
            metadataTem.metadataURL = metadataURLs[i];
            metadata[tokenId] = metadataTem;

            emit MintedNFT(
                to,
                tokenId,
                masterId,
                startingPrintNumber,
                remainingUses[tokenId]
            );
        }
    }

    // // 发起盲盒请求
    // function mintBatchPrintEditionRandomMasters(
    //     address to,
    //     uint256[] calldata masterIds,
    //     uint256 totalAmount
    // ) external whenNotPaused nonReentrant {
    //     for (uint256 i = 0; i < masterIds.length; i++) {
    //         require(
    //             isWhiteListed[msg.sender][masterIds[i]] ||
    //                 msg.sender == owner(),
    //             "Not whitelisted"
    //         );
    //     } // 检查 msg.sender 是否在所有masterId白名单内
    //     require(masterIds.length > 0, "No master IDs provided");
    //     require(
    //         nextTokenId + totalAmount + reservedSupply - 1 <= maxSupply,
    //         "Exceeds max supply"
    //     );
    //     reservedSupply += totalAmount; // Reserve immediately

    //     uint256 requestId = ++nextRequestId;
    //     requests[requestId] = RequestInfo({
    //         receiver: to,
    //         totalAmount: totalAmount,
    //         masterIds: masterIds,
    //         fulfilled: false
    //     });

    //     // 请求随机数
    //     vrfPod.requestRandomWords(requestId, totalAmount);

    //     emit MintRequested(requestId, to, totalAmount, masterIds);
    // }

    // // Oracle fulfill 回调
    // // 由 VRF Manager 调用 Pod，然后 Pod 再回调此函数
    // function rawFulfillRandomWords(
    //     uint256 requestId,
    //     uint256[] calldata randomWords
    // ) external returns (uint256[] memory) {
    //     // 安全：只能来自 VRF Pod
    //     require(msg.sender == address(vrfPod), "Unauthorized");

    //     RequestInfo storage req = requests[requestId];
    //     require(!req.fulfilled, "Already fulfilled");
    //     require(req.receiver != address(0), "Invalid request");

    //     uint256[] memory masterIds = req.masterIds;
    //     uint256 totalAmount = req.totalAmount;
    //     address to = req.receiver;

    //     uint256[] memory chosen = new uint256[](totalAmount);

    //     reservedSupply -= totalAmount; // Release reservation

    //     for (uint256 i = 0; i < totalAmount; i++) {
    //         // 使用随机数选择 Master ID
    //         uint256 randomIndex = randomWords[i] % masterIds.length;

    //         uint256 masterId = masterIds[randomIndex];
    //         require(isMaster[masterId], "Invalid masterId");
    //         chosen[i] = masterId;

    //         uint256 tokenId = nextTokenId++;

    //         _safeMint(to, tokenId);

    //         // 标记为非 Master
    //         isMaster[tokenId] = false;
    //         fromMaster[tokenId] = masterId;

    //         // 随机生成 print edition 编号，确保不重复
    //         uint256 startingPrintNumber = 1;
    //         while (isPrintExist[masterId][startingPrintNumber]) {
    //             startingPrintNumber++;
    //         }

    //         printEditionNumber[tokenId] = startingPrintNumber;
    //         isPrintExist[masterId][startingPrintNumber] = true;

    //         // 继承 Master 的 metadata
    //         metadata[tokenId] = metadata[masterId];
    //         remainingUses[tokenId] = metadata[masterId].usageLimit;

    //         emit MintedNFT(
    //             to,
    //             tokenId,
    //             masterId,
    //             startingPrintNumber,
    //             remainingUses[tokenId]
    //         );
    //     }

    //     req.fulfilled = true;
    //     emit MintCompleted(requestId, chosen);
    //     return chosen;
    // }

    // -----------------------
    //   发起 mint 盲盒请求
    // -----------------------
    function mintBatchPrintEditionRandomMasters(
        address to,
        uint256[] calldata masterIds,
        uint256 totalAmount
    ) external onlyWhiteListed whenNotPaused nonReentrant {
        for (uint256 i = 0; i < masterIds.length; i++) {
            require(
                isEditer[msg.sender][masterIds[i]] || msg.sender == owner(),
                "No Access to eidt"
            );
        } // 检查 msg.sender 是否在所有masterId编辑权限内

        _requestRandomMint(to, masterIds, totalAmount);
    }

    /**
     * @dev 内部函数：处理 VRF 随机铸造请求的统一逻辑
     */
    function _requestRandomMint(
        address to,
        uint256[] memory masterIds,
        uint256 totalAmount
    ) internal {
        require(masterIds.length > 0, "No master IDs provided");
        require(
            nextTokenId + totalAmount + reservedSupply - 1 <= maxSupply,
            "Exceeds max supply"
        );

        reservedSupply += totalAmount;

        uint256 requestId = ++nextRequestId;

        requests[requestId] = RequestInfo({
            receiver: to,
            totalAmount: totalAmount,
            masterIds: masterIds,
            fulfilled: false
        });

        _enqueue(requestId);

        // 请求随机数
        vrfPod.requestRandomWords(requestId, totalAmount);

        emit MintRequested(requestId, to, totalAmount, masterIds);
    }

    // Oracle fulfill 回调
    // 由 VRF Manager 调用 Pod，然后 Pod 再回调此函数
    function rawFulfillRandomWords(
        // uint256 requestId,
        uint256[] calldata randomWords
    ) external returns (uint256[] memory) {
        // 安全：只能来自 VRF Pod
        require(msg.sender == address(vrfPod), "Unauthorized");

        require(randomWords.length > 0, "No random words");

        uint256 requestId = _dequeue();
        RequestInfo storage req = requests[requestId];

        require(!req.fulfilled, "Already fulfilled");
        require(req.receiver != address(0), "Invalid request");

        uint256[] memory masterIds = req.masterIds;
        uint256 totalAmount = req.totalAmount;
        address to = req.receiver;

        uint256[] memory chosen = new uint256[](totalAmount);

        reservedSupply -= totalAmount; // Release reservation

        for (uint256 i = 0; i < totalAmount; i++) {
            uint256 baseRandom;

            if (i < randomWords.length) {
                baseRandom = randomWords[i];
            } else {
                // 用 VRF 基础随机 + i + requestId 进行扩展
                baseRandom = uint256(
                    keccak256(
                        abi.encode(
                            randomWords[i % randomWords.length],
                            requestId,
                            i
                        )
                    )
                );
            }

            // 使用随机数选择 Master ID
            uint256 randomIndex = baseRandom % masterIds.length;
            uint256 masterId = masterIds[randomIndex];

            require(isMaster[masterId], "Invalid masterId");
            chosen[i] = masterId;

            uint256 tokenId = nextTokenId++;

            _safeMint(to, tokenId);

            // 标记为非 Master
            isMaster[tokenId] = false;
            fromMaster[tokenId] = masterId;

            // 随机生成 print edition 编号，确保不重复
            uint256 startingPrintNumber = 1;
            while (isPrintExist[masterId][startingPrintNumber]) {
                startingPrintNumber++;
            }

            printEditionNumber[tokenId] = startingPrintNumber;
            isPrintExist[masterId][startingPrintNumber] = true;

            // 继承 Master 的 metadata
            metadata[tokenId] = metadata[masterId];
            remainingUses[tokenId] = metadata[masterId].usageLimit;

            emit MintedNFT(
                to,
                tokenId,
                masterId,
                startingPrintNumber,
                remainingUses[tokenId]
            );
        }

        req.fulfilled = true;
        emit MintCompleted(requestId, chosen);
        return chosen;
    }

    // ===================== Metadata =====================
    function setBaseURI(string memory _uri) external onlyOwner {
        baseURI = _uri;
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        _requireOwned(tokenId);

        NFTMetadata memory md = metadata[tokenId];

        return md.metadataURL;
    }

    // ===================== 版税（EIP-2981） =====================
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) public view returns (address receiver, uint256 royaltyAmount) {
        NFTMetadata memory md = metadata[tokenId];
        receiver = md.royaltyReceiver;
        if (receiver == address(0) || md.royaltyBps == 0) {
            return (address(0), 0);
        }
        // 计算版税金额
        royaltyAmount = (salePrice * md.royaltyBps) / 10000;
    }

    // ===================== 转移规则 =====================
    function lockTransfer(uint256 tokenId) external onlyWhiteListed {
        _requireOwned(tokenId);

        transferLocked[tokenId] = true;
    }

    function unlockTransfer(uint256 tokenId) external onlyWhiteListed {
        _requireOwned(tokenId);

        transferLocked[tokenId] = false;
    }

    // ====================== 核销使用次数, 必须tokenId的拥有者调用 =====================
    function useNFT(uint256 tokenId) public nonReentrant whenNotPaused {
        _requireOwned(tokenId);
        require(transferLocked[tokenId], "Token must be locked to use");
        require(
            msg.sender == owner() ||
                isEditer[msg.sender][fromMaster[tokenId]] ||
                isChecker[msg.sender][fromMaster[tokenId]],
            "Not authorized"
        );
        require(remainingUses[tokenId] > 0, "No remaining uses");
        remainingUses[tokenId]--;

        // // 核销次数用完即销毁
        // if (remainingUses[tokenId] == 0) {
        //     burn(tokenId);
        // }
        emit NFTUsed(tokenId, remainingUses[tokenId], block.timestamp);
    }

    // ===================== 内部函数 =====================
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // function _exists(uint256 tokenId) internal view returns (bool) {
    //     address owner = _ownerOf(tokenId);
    //     if (owner == address(0)) {
    //         return false;
    //     }
    //     return true;
    // }

    // ============== 设置参数 =====================
    function setMaxSupply(uint256 maxSupply_) external onlyOwner {
        require(maxSupply_ >= nextTokenId - 1, "Cannot set less than minted");
        maxSupply = maxSupply_;
    }

    function setRoyaltyInfo(
        uint256 tokenId,
        address receiver,
        uint96 royaltyBps
    ) external {
        _requireOwned(tokenId);
        require(
            msg.sender == owner() || msg.sender == ownerOf(tokenId),
            "Not authorized"
        );
        require(receiver != address(0), "Invalid receiver");
        metadata[tokenId].royaltyReceiver = receiver;
        metadata[tokenId].royaltyBps = royaltyBps;
    }

    // ===================== white list =====================
    function setWhiteList(address operator, bool approved) public onlyOwner {
        isWhiteListed[operator] = approved;
    }

    function setEditer(
        address operator,
        bool approved,
        uint256 masterId
    ) public onlyOwner {
        isEditer[operator][masterId] = approved;
    }

    function setChecker(
        address operator,
        bool approved,
        uint256 masterId
    ) public onlyEditer(masterId) {
        isChecker[operator][masterId] = approved;
    }

    function setVrfPod(address _vrfPod) external onlyOwner {
        vrfPod = IVrfPod(_vrfPod);
    }

    // ===================== view functions =====================
    function getMetadata(
        uint256 tokenId
    ) external view returns (NFTMetadata memory) {
        _requireOwned(tokenId);
        return metadata[tokenId];
    }

    function totalMinted() public view returns (uint256) {
        return nextTokenId - 1;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ===================== 转移NFT =====================
    // Override ERC721Upgradeable, IERC721
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721Upgradeable, IERC721) {
        require(!transferLocked[tokenId], "Transfer locked for this NFT");
        require(remainingUses[tokenId] > 0, "NFT has no remaining uses");

        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override(ERC721Upgradeable, IERC721) {
        require(!transferLocked[tokenId], "Transfer locked for this NFT");
        require(remainingUses[tokenId] > 0, "NFT has no remaining uses");
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes memory data
    // ) public virtual {
    //     transferFrom(from, to, tokenId);
    //     ERC721Utils.checkOnERC721Received(
    //         _msgSender(),
    //         from,
    //         to,
    //         tokenId,
    //         data
    //     );
    // }
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 amount
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, amount);
    }

    // ===================== 支持接口 =====================
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable
        )
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ===================== New Requirements Implementation =====================

    /**
     * @notice 上架 Master Edition 并设置金额和收款 Token
     * @param masterId Master NFT 的 ID
     * @param price 价格
     * @param paymentToken 收款代币地址 (address(0) 表示 Native ETH)
     */
    function listMasterEdition(
        uint256 masterId,
        uint256 price,
        address paymentToken
    ) external {
        require(isMaster[masterId], "Not a master edition");
        require(ownerOf(masterId) == msg.sender, "Not the owner of master");

        masterSales[masterId] = MasterSale({
            price: price,
            paymentToken: paymentToken,
            isForSale: true
        });

        emit MasterEditionListed(masterId, price, paymentToken);
    }

    /**
     * @notice 取消上架
     */
    function unlistMasterEdition(uint256 masterId) external {
        require(ownerOf(masterId) == msg.sender, "Not the owner");
        masterSales[masterId].isForSale = false;
        emit MasterEditionUnlisted(masterId);
    }

    /**
     * @notice 修改已上架 Master Edition 的销售信息（价格、收款代币）
     * @param masterId Master NFT 的 ID
     * @param newPrice 新价格
     * @param newPaymentToken 新的收款代币地址 (address(0) 表示 Native ETH)
     */
    function updateMasterSale(
        uint256 masterId,
        uint256 newPrice,
        address newPaymentToken
    ) external {
        require(ownerOf(masterId) == msg.sender, "Not the owner");
        require(masterSales[masterId].isForSale, "Not listed for sale");

        masterSales[masterId].price = newPrice;
        masterSales[masterId].paymentToken = newPaymentToken;

        emit MasterEditionListed(masterId, newPrice, newPaymentToken);
    }

    /**
     * @notice 买家购买 Master Edition，付款并自动 Mint 印刷版
     * @param masterId 想要购买哪个 Master 的 Print
     */
    function buyPrintEdition(
        uint256 masterId
    ) external payable nonReentrant whenNotPaused {
        MasterSale memory sale = masterSales[masterId];
        require(sale.isForSale, "Master edition not for sale");
        require(nextTokenId <= maxSupply, "Exceeds max supply");

        address masterOwner = ownerOf(masterId);

        // 计算手续费
        uint256 feeAmount = (sale.price * platformFeeBps) / 10000;
        uint256 sellerAmount = sale.price - feeAmount;

        // 处理付款
        if (sale.paymentToken == address(0)) {
            require(msg.value >= sale.price, "Insufficient ETH sent");
            // 将手续费转给 feeReceiver
            if (feeAmount > 0 && feeReceiver != address(0)) {
                (bool feeSuccess, ) = payable(feeReceiver).call{
                    value: feeAmount
                }("");
                require(feeSuccess, "Fee transfer failed");
            }
            // 将剩余款项转给 Master 拥有者
            (bool success, ) = payable(masterOwner).call{value: sellerAmount}(
                ""
            );
            require(success, "ETH transfer failed");
            // 退回多余的 ETH
            if (msg.value > sale.price) {
                (bool returnSuccess, ) = payable(msg.sender).call{
                    value: msg.value - sale.price
                }("");
                require(returnSuccess, "ETH return failed");
            }
        } else {
            // ERC20: 手续费转给 feeReceiver
            if (feeAmount > 0 && feeReceiver != address(0)) {
                IERC20(sale.paymentToken).safeTransferFrom(
                    msg.sender,
                    feeReceiver,
                    feeAmount
                );
            }
            // ERC20: 剩余部分转给卖家
            IERC20(sale.paymentToken).safeTransferFrom(
                msg.sender,
                masterOwner,
                sellerAmount
            );
        }

        // 自动查找下一个可用的 Print Number
        uint256 printNumber = 1;
        while (isPrintExist[masterId][printNumber]) {
            printNumber++;
        }

        // 执行 Mint 逻辑 (参考 mintPrintEdition)
        uint256 tokenId = nextTokenId++;
        _safeMint(msg.sender, tokenId);

        isMaster[tokenId] = false;
        fromMaster[tokenId] = masterId;
        printEditionNumber[tokenId] = printNumber;
        isPrintExist[masterId][printNumber] = true;

        // 继承 Master 的元数据
        NFTMetadata memory masterMd = metadata[masterId];
        metadata[tokenId] = masterMd;
        remainingUses[tokenId] = masterMd.usageLimit;

        emit MintedNFT(
            msg.sender,
            tokenId,
            masterId,
            printNumber,
            masterMd.usageLimit
        );

        emit PrintEditionPurchased(masterId, tokenId, msg.sender, sale.price);
    }

    // ===================== Fee Config =====================

    /**
     * @notice Owner 配置平台手续费
     * @param _feeBps 手续费比例（BP，例如 250 = 2.5%，最大 5000 = 50%）
     * @param _feeReceiver 手续费接收地址
     */
    function setFeeConfig(
        uint256 _feeBps,
        address _feeReceiver
    ) external onlyOwner {
        require(_feeBps <= 5000, "Fee too high"); // 最高 50%
        require(_feeReceiver != address(0), "Invalid fee receiver");
        platformFeeBps = _feeBps;
        feeReceiver = _feeReceiver;
        emit FeeConfigUpdated(_feeBps, _feeReceiver);
    }

    // ===================== Blind Box =====================

    /**
     * @notice 创建盲盒活动
     * @param _masterIds 候选 Master ID 列表
     * @param _mintPerDraw 每次抽盲盒 mint 的 Print 数量
     * @param _price 每次抽盲盒的价格
     * @param _paymentToken 付款代币地址 (address(0) 表示 ETH)
     * @param _expireAt 过期时间戳，传 0 表示不自动过期
     */
    function createBlindBox(
        uint256[] calldata _masterIds,
        uint256 _mintPerDraw,
        uint256 _price,
        address _paymentToken,
        uint256 _expireAt
    ) external onlyWhiteListed returns (uint256) {
        require(_masterIds.length > 0, "No master IDs provided");
        require(_mintPerDraw > 0, "Mint per draw must be > 0");
        if (_expireAt != 0) {
            require(
                _expireAt > block.timestamp,
                "Expire time must be in the future"
            );
        }

        // 校验所有 masterIds 有效且调用者有编辑权限
        for (uint256 i = 0; i < _masterIds.length; i++) {
            require(isMaster[_masterIds[i]], "Invalid masterId");
            require(
                isEditer[msg.sender][_masterIds[i]] || msg.sender == owner(),
                "No editor access for masterId"
            );
        }

        uint256 blindBoxId = ++nextBlindBoxId;
        blindBoxCampaigns[blindBoxId] = BlindBoxCampaign({
            masterIds: _masterIds,
            mintPerDraw: _mintPerDraw,
            price: _price,
            paymentToken: _paymentToken,
            creator: msg.sender,
            expireAt: _expireAt,
            isActive: true
        });

        emit BlindBoxCreated(
            blindBoxId,
            msg.sender,
            _masterIds,
            _mintPerDraw,
            _price,
            _paymentToken,
            _expireAt
        );
        return blindBoxId;
    }

    /**
     * @notice 用户付款抽盲盒，自动随机 Mint Print Edition
     * @param blindBoxId 盲盒活动 ID
     */
    function redeemBlindBox(
        uint256 blindBoxId
    ) external payable nonReentrant whenNotPaused {
        BlindBoxCampaign storage campaign = blindBoxCampaigns[blindBoxId];
        require(campaign.isActive, "Blind box not active");
        if (campaign.expireAt != 0) {
            require(block.timestamp <= campaign.expireAt, "Blind box expired");
        }
        require(
            nextTokenId + campaign.mintPerDraw - 1 <= maxSupply,
            "Exceeds max supply"
        );

        // 计算手续费
        uint256 feeAmount = (campaign.price * platformFeeBps) / 10000;
        uint256 sellerAmount = campaign.price - feeAmount;

        // 处理付款
        if (campaign.paymentToken == address(0)) {
            require(msg.value >= campaign.price, "Insufficient ETH sent");
            // 手续费转给 feeReceiver
            if (feeAmount > 0 && feeReceiver != address(0)) {
                (bool feeSuccess, ) = payable(feeReceiver).call{
                    value: feeAmount
                }("");
                require(feeSuccess, "Fee transfer failed");
            }
            // 剩余款项转给创建者
            (bool success, ) = payable(campaign.creator).call{
                value: sellerAmount
            }("");
            require(success, "ETH transfer failed");
            // 退回多余的 ETH
            if (msg.value > campaign.price) {
                (bool returnSuccess, ) = payable(msg.sender).call{
                    value: msg.value - campaign.price
                }("");
                require(returnSuccess, "ETH return failed");
            }
        } else {
            if (feeAmount > 0 && feeReceiver != address(0)) {
                IERC20(campaign.paymentToken).safeTransferFrom(
                    msg.sender,
                    feeReceiver,
                    feeAmount
                );
            }
            IERC20(campaign.paymentToken).safeTransferFrom(
                msg.sender,
                campaign.creator,
                sellerAmount
            );
        }

        // 提交 VRF 随机铸造请求 (复用核心逻辑)
        _requestRandomMint(
            msg.sender,
            campaign.masterIds,
            campaign.mintPerDraw
        );

        // 注意：由于使用了 VRF，实际的 Mint 动作将在 rawFulfillRandomWords 中异步完成作业
        // 这意味着 BlindBoxRedeemed 事件在此时无法拿到具体的 tokenIds
        emit BlindBoxRedeemed(
            blindBoxId,
            msg.sender,
            new uint256[](0),
            campaign.masterIds
        );
    }

    /**
     * @notice 取消盲盒活动（创建者或 Owner 可调用）
     * @param blindBoxId 盲盒活动 ID
     */
    function cancelBlindBox(uint256 blindBoxId) external {
        BlindBoxCampaign storage campaign = blindBoxCampaigns[blindBoxId];
        require(campaign.isActive, "Blind box not active");
        require(
            msg.sender == campaign.creator || msg.sender == owner(),
            "Not authorized"
        );
        campaign.isActive = false;
        emit BlindBoxCancelled(blindBoxId);
    }

    /**
     * @notice 修改盲盒活动信息
     * @param blindBoxId 盲盒活动 ID
     * @param _masterIds 新的候选 Master ID 列表
     * @param _mintPerDraw 新的每次抽盲盒 mint 的数量
     * @param _price 新的价格
     * @param _paymentToken 新的付款代币地址
     * @param _expireAt 新的过期时间戳
     * @param _isActive 是否激活
     */
    function updateBlindBox(
        uint256 blindBoxId,
        uint256[] calldata _masterIds,
        uint256 _mintPerDraw,
        uint256 _price,
        address _paymentToken,
        uint256 _expireAt,
        bool _isActive
    ) external {
        BlindBoxCampaign storage campaign = blindBoxCampaigns[blindBoxId];
        require(
            msg.sender == campaign.creator || msg.sender == owner(),
            "Not authorized"
        );
        require(_masterIds.length > 0, "No master IDs provided");
        require(_mintPerDraw > 0, "Mint per draw must be > 0");

        // 校验所有 masterIds 有效且调用者有编辑权限
        for (uint256 i = 0; i < _masterIds.length; i++) {
            require(isMaster[_masterIds[i]], "Invalid masterId");
            require(
                isEditer[msg.sender][_masterIds[i]] || msg.sender == owner(),
                "No editor access for masterId"
            );
        }

        campaign.masterIds = _masterIds;
        campaign.mintPerDraw = _mintPerDraw;
        campaign.price = _price;
        campaign.paymentToken = _paymentToken;
        campaign.expireAt = _expireAt;
        campaign.isActive = _isActive;

        emit BlindBoxCreated(
            blindBoxId,
            campaign.creator,
            _masterIds,
            _mintPerDraw,
            _price,
            _paymentToken,
            _expireAt
        );
    }

    /**
     * @notice 查询盲盒活动详情
     * @param blindBoxId 盲盒活动 ID
     */
    function getBlindBoxCampaign(
        uint256 blindBoxId
    )
        external
        view
        returns (
            uint256[] memory masterIds,
            uint256 mintPerDraw,
            uint256 price,
            address paymentToken,
            address creator,
            uint256 expireAt,
            bool isActive
        )
    {
        BlindBoxCampaign storage c = blindBoxCampaigns[blindBoxId];
        return (
            c.masterIds,
            c.mintPerDraw,
            c.price,
            c.paymentToken,
            c.creator,
            c.expireAt,
            c.isActive
        );
    }

    uint256[40] private __gap; // 原 45，减 5 slot (masterSales + platformFeeBps + feeReceiver + nextBlindBoxId + blindBoxCampaigns)
}
