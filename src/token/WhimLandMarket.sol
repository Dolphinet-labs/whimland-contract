// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface INFTManager {
    function isMaster(uint256 tokenId) external view returns (bool);

    function ownerOf(uint256 tokenId) external view returns (address);

    function mintPrintEdition(
        address to,
        uint256 masterId,
        uint256 printNumber,
        string memory metadataURL
    ) external returns (uint256);

    function mintBatchPrintEditionRandomMasters(
        address to,
        uint256[] memory masterIds,
        uint256 totalAmount
    ) external;

    function isPrintExist(
        uint256 masterId,
        uint256 printNumber
    ) external view returns (bool);
}

contract WhimLandMarket is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    INFTManager public nftManager;

    uint256 public platformFeeBps;
    address public feeReceiver;

    // 常量：销售版 Print Edition 的起始编号（从 10 亿开始递减）
    uint256 public constant SALE_PRINT_START_ID = 10 ** 9;

    struct MasterSale {
        uint256 price;
        address paymentToken;
        bool isForSale;
        string metadataURL; // 该上架对应的元数据 URL
        uint256 nextPrintNumber; // 下一个可用的编号（递减）
    }
    mapping(uint256 => MasterSale) public masterSales;

    struct BlindBoxCampaign {
        uint256[] masterIds;
        uint256 mintPerDraw;
        uint256 price;
        address paymentToken;
        address creator;
        uint256 expireAt;
        bool isActive;
    }
    uint256 public nextBlindBoxId;
    mapping(uint256 => BlindBoxCampaign) public blindBoxCampaigns;

    // ============== Events =====================
    event MasterEditionListed(
        uint256 indexed masterId,
        uint256 price,
        address paymentToken,
        string metadataURL
    );
    event MasterEditionUnlisted(uint256 indexed masterId);
    event PrintEditionPurchased(
        uint256 indexed masterId,
        address buyer,
        uint256 price,
        uint256 printNumber
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
        uint256 price
    );
    event BlindBoxCancelled(uint256 indexed blindBoxId);
    event FeeConfigUpdated(uint256 feeBps, address feeReceiver);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _nftManager,
        address _initialOwner
    ) public initializer {
        __Ownable_init(_initialOwner);
        __ReentrancyGuard_init();

        nftManager = INFTManager(_nftManager);
    }

    // ===================== Listing Logic =====================

    /**
     * @notice 上架 Master Edition
     * @param masterId Master ID
     * @param price 价格
     * @param paymentToken 收款 Token
     * @param metadataURL 该印刷版专用的 URL
     */
    function listMasterEdition(
        uint256 masterId,
        uint256 price,
        address paymentToken,
        string calldata metadataURL
    ) external {
        require(nftManager.isMaster(masterId), "Not a master edition");
        require(nftManager.ownerOf(masterId) == msg.sender, "Not the owner");

        masterSales[masterId] = MasterSale({
            price: price,
            paymentToken: paymentToken,
            isForSale: true,
            metadataURL: metadataURL,
            nextPrintNumber: SALE_PRINT_START_ID
        });
        emit MasterEditionListed(masterId, price, paymentToken, metadataURL);
    }

    function unlistMasterEdition(uint256 masterId) external {
        require(nftManager.ownerOf(masterId) == msg.sender, "Not the owner");
        masterSales[masterId].isForSale = false;
        emit MasterEditionUnlisted(masterId);
    }

    function updateMasterSale(
        uint256 masterId,
        uint256 newPrice,
        address newPaymentToken,
        string calldata newMetadataURL
    ) external {
        MasterSale storage sale = masterSales[masterId];
        require(nftManager.ownerOf(masterId) == msg.sender, "Not the owner");
        require(sale.isForSale, "Not listed");

        sale.price = newPrice;
        sale.paymentToken = newPaymentToken;
        sale.metadataURL = newMetadataURL;

        emit MasterEditionListed(
            masterId,
            newPrice,
            newPaymentToken,
            newMetadataURL
        );
    }

    /**
     * @notice 购买印刷版，现在使用递减编号且通过销售配置传入 URL
     */
    function buyPrintEdition(uint256 masterId) external payable nonReentrant {
        MasterSale storage sale = masterSales[masterId];
        require(sale.isForSale, "Not for sale");

        _handlePayment(
            sale.price,
            sale.paymentToken,
            nftManager.ownerOf(masterId)
        );

        // 优化点：使用递减编号，避免 Gas 密集的循环查找
        uint256 printNumber = sale.nextPrintNumber;
        sale.nextPrintNumber--;

        // 使用存储在 sale 中的 metadataURL
        nftManager.mintPrintEdition(
            msg.sender,
            masterId,
            printNumber,
            sale.metadataURL
        );

        emit PrintEditionPurchased(
            masterId,
            msg.sender,
            sale.price,
            printNumber
        );
    }

    // ===================== Blind Box Logic =====================

    function createBlindBox(
        uint256[] calldata _masterIds,
        uint256 _mintPerDraw,
        uint256 _price,
        address _paymentToken,
        uint256 _expireAt
    ) external returns (uint256) {
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

    function redeemBlindBox(uint256 blindBoxId) external payable nonReentrant {
        BlindBoxCampaign storage campaign = blindBoxCampaigns[blindBoxId];
        require(campaign.isActive, "Not active");
        if (campaign.expireAt != 0)
            require(block.timestamp <= campaign.expireAt, "Expired");

        _handlePayment(campaign.price, campaign.paymentToken, campaign.creator);

        // 调用 NFTManager 发起随机 Mint 请求
        nftManager.mintBatchPrintEditionRandomMasters(
            msg.sender,
            campaign.masterIds,
            campaign.mintPerDraw
        );

        emit BlindBoxRedeemed(blindBoxId, msg.sender, campaign.price);
    }

    /**
     * @notice 更新现有盲盒活动的配置
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

        // 校验所有 masterIds 有效
        for (uint256 i = 0; i < _masterIds.length; i++) {
            require(nftManager.isMaster(_masterIds[i]), "Invalid masterId");
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

    function cancelBlindBox(uint256 blindBoxId) external {
        BlindBoxCampaign storage campaign = blindBoxCampaigns[blindBoxId];
        require(
            msg.sender == campaign.creator || msg.sender == owner(),
            "No access"
        );
        campaign.isActive = false;
        emit BlindBoxCancelled(blindBoxId);
    }

    // ===================== Internal Helpers =====================

    function _handlePayment(
        uint256 amount,
        address token,
        address seller
    ) internal {
        uint256 fee = (amount * platformFeeBps) / 10000;
        uint256 sellerAmount = amount - fee;

        if (token == address(0)) {
            require(msg.value >= amount, "Insuff. ETH");
            if (fee > 0 && feeReceiver != address(0)) {
                (bool success, ) = payable(feeReceiver).call{value: fee}("");
                require(success, "Fee transfer failed");
            }
            (bool sellerSuccess, ) = payable(seller).call{value: sellerAmount}(
                ""
            );
            require(sellerSuccess, "Seller transfer failed");

            if (msg.value > amount) {
                (bool refundSuccess, ) = payable(msg.sender).call{
                    value: msg.value - amount
                }("");
                require(refundSuccess, "Refund failed");
            }
        } else {
            if (fee > 0 && feeReceiver != address(0))
                IERC20(token).safeTransferFrom(msg.sender, feeReceiver, fee);
            IERC20(token).safeTransferFrom(msg.sender, seller, sellerAmount);
        }
    }

    function setFeeConfig(
        uint256 _feeBps,
        address _feeReceiver
    ) external onlyOwner {
        require(_feeBps <= 5000, "Too high");
        platformFeeBps = _feeBps;
        feeReceiver = _feeReceiver;
        emit FeeConfigUpdated(_feeBps, _feeReceiver);
    }

    uint256[48] private __gap;
}
