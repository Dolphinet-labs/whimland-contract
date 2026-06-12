// AI 宠物合约
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @notice NFTManager 的最小销毁接口（见 NFTManager.petBurn）。
 */
interface IPetBurnable {
    function ownerOf(uint256 tokenId) external view returns (address);
    function petBurn(uint256 tokenId) external;
}

/**
 * @title WhimPet — Whimland AI 宠物
 *
 * 独立于商品合约（NFTManager）的宠物 ERC-721：
 * - 领养 adoptPet：跨合约原子化销毁商品 NFT（NFTManager.petBurn）+ 铸造宠物
 * - 喂养 feedPet：销毁商品 NFT + 宠物等级 +1 + 更新元数据（ERC-4906）
 * - 默认灵魂绑定（transfersEnabled=false），未来可由 owner 开放交易
 * - 全平台唯一宠物 collection，支持来自任意已部署 NFTManager 的商品销毁
 *
 * 所有操作由平台 petOperator（后端热钱包）代执行，用户无需付 gas。
 */
contract WhimPet is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    // ============== Storage =====================
    uint256 public nextTokenId;
    address public petOperator; // 平台宠物操作钱包
    bool public transfersEnabled; // 全局转移开关（默认 false = 灵魂绑定）

    mapping(uint256 => uint256) public petLevel; // 喂养次数
    mapping(uint256 => string) private _metadataURL;
    // 来源记录（可审计：这只宠物烧了哪个商品）
    mapping(uint256 => address) public sourceContract;
    mapping(uint256 => uint256) public sourceTokenId;

    // ============== Events =====================
    event PetAdopted(
        address indexed owner,
        address indexed burnContract,
        uint256 burnedTokenId,
        uint256 indexed petTokenId
    );
    event PetEvolved(
        uint256 indexed petTokenId,
        address indexed burnContract,
        uint256 burnedTokenId,
        uint256 newLevel
    );
    event PetOperatorChanged(address indexed previousOperator, address indexed newOperator);
    event TransfersEnabledChanged(bool enabled);

    // ERC-4906
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    // ============== Modifiers =====================
    modifier onlyPetOperator() {
        require(
            msg.sender == petOperator || msg.sender == owner(),
            "Not pet operator"
        );
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address _initialOwner
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);
        __Pausable_init();
        nextTokenId = 1;
    }

    // ===================== 领养 / 喂养 =====================

    /**
     * @notice 领养：销毁用户持有的商品 NFT（任意 NFTManager），同一笔交易内铸造宠物。
     * @param burnContract 商品 NFT 所在的 NFTManager 合约
     * @param burnTokenId  被销毁的商品 NFT
     * @param petOwner     宠物接收者（必须是 burnTokenId 当前持有人）
     * @param metadataURL  宠物初始元数据 URL
     */
    function adoptPet(
        address burnContract,
        uint256 burnTokenId,
        address petOwner,
        string memory metadataURL
    ) external onlyPetOperator whenNotPaused nonReentrant returns (uint256) {
        require(petOwner != address(0), "Invalid pet owner");

        IPetBurnable nm = IPetBurnable(burnContract);
        require(nm.ownerOf(burnTokenId) == petOwner, "Not token owner");
        nm.petBurn(burnTokenId);

        uint256 petTokenId = nextTokenId++;
        _safeMint(petOwner, petTokenId);

        _metadataURL[petTokenId] = metadataURL;
        sourceContract[petTokenId] = burnContract;
        sourceTokenId[petTokenId] = burnTokenId;

        emit PetAdopted(petOwner, burnContract, burnTokenId, petTokenId);
        return petTokenId;
    }

    /**
     * @notice 喂养：销毁商品 NFT，宠物等级 +1 并更新形象元数据。
     * @param burnContract   被喂商品所在的 NFTManager 合约
     * @param burnTokenId    被喂掉（销毁）的商品 NFT
     * @param petTokenId     目标宠物
     * @param newMetadataURL 进化后的新元数据 URL
     */
    function feedPet(
        address burnContract,
        uint256 burnTokenId,
        uint256 petTokenId,
        string memory newMetadataURL
    ) external onlyPetOperator whenNotPaused nonReentrant {
        address petHolder = ownerOf(petTokenId);

        IPetBurnable nm = IPetBurnable(burnContract);
        require(nm.ownerOf(burnTokenId) == petHolder, "Owner mismatch");
        nm.petBurn(burnTokenId);

        petLevel[petTokenId] += 1;
        _metadataURL[petTokenId] = newMetadataURL;

        emit PetEvolved(petTokenId, burnContract, burnTokenId, petLevel[petTokenId]);
        emit MetadataUpdate(petTokenId);
    }

    /**
     * @notice 更新宠物元数据 URL（Gallery 切换展示形象 / 活动皮肤佩戴）。
     */
    function setPetMetadataURL(
        uint256 petTokenId,
        string memory newMetadataURL
    ) external onlyPetOperator whenNotPaused {
        _requireOwned(petTokenId);
        _metadataURL[petTokenId] = newMetadataURL;
        emit MetadataUpdate(petTokenId);
    }

    // ===================== Metadata =====================

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _metadataURL[tokenId];
    }

    // ===================== 灵魂绑定 / 转移控制 =====================

    /**
     * @dev mint/burn 始终允许；持有人间转移仅在 transfersEnabled 时放行。
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            require(transfersEnabled, "Soulbound: transfers disabled");
        }
        return super._update(to, tokenId, auth);
    }

    // ===================== 管理 =====================

    function setPetOperator(address _petOperator) external onlyOwner {
        emit PetOperatorChanged(petOperator, _petOperator);
        petOperator = _petOperator;
    }

    function setTransfersEnabled(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
        emit TransfersEnabledChanged(enabled);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ===================== views =====================

    function totalMinted() public view returns (uint256) {
        return nextTokenId - 1;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return
            interfaceId == bytes4(0x49064906) || // ERC-4906 Metadata Update
            super.supportsInterface(interfaceId);
    }

    uint256[44] private __gap;
}
