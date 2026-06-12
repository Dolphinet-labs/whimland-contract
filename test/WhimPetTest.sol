// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NFTManager} from "../src/token/NFTManager.sol";
import {WhimPet} from "../src/token/WhimPet.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract WhimPetTest is Test {
    NFTManager internal nft;
    NFTManager internal nft2; // 第二个 NFTManager，验证跨多合约领养/喂养
    WhimPet internal pet;

    address internal owner = makeAddr("owner");
    address internal petOperator = makeAddr("petOperator");
    address internal user = makeAddr("user");
    address internal stranger = makeAddr("stranger");

    uint256 internal masterId;
    uint256 internal printId;

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
    event MetadataUpdate(uint256 _tokenId);

    function _deployNFTManager() internal returns (NFTManager) {
        NFTManager impl = new NFTManager();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            makeAddr("proxyAdmin"),
            abi.encodeCall(
                NFTManager.initialize,
                ("Whimland", "WHIM", 1_000_000, "", owner, address(0))
            )
        );
        return NFTManager(payable(address(proxy)));
    }

    function setUp() public {
        nft = _deployNFTManager();
        nft2 = _deployNFTManager();

        WhimPet petImpl = new WhimPet();
        TransparentUpgradeableProxy petProxy = new TransparentUpgradeableProxy(
            address(petImpl),
            makeAddr("petProxyAdmin"),
            abi.encodeCall(WhimPet.initialize, ("Whimland Pets", "WHIMPET", owner))
        );
        pet = WhimPet(address(petProxy));

        vm.startPrank(owner);
        pet.setPetOperator(petOperator);
        nft.setPetSystem(address(pet));
        nft2.setPetSystem(address(pet));

        masterId = nft.mintMaster(
            owner,
            NFTManager.NFTMetadata({
                name: "Toy",
                description: "A product master",
                metadataURL: "https://meta/master.json",
                royaltyBps: 500,
                royaltyReceiver: owner,
                usageLimit: 1
            })
        );
        printId = nft.mintPrintEdition(user, masterId, 1, "https://meta/print-1.json");
        vm.stopPrank();
    }

    function _mintPrintTo(NFTManager target, address to, uint256 printNumber) internal returns (uint256) {
        vm.startPrank(owner);
        uint256 mid = target.mintMaster(
            owner,
            NFTManager.NFTMetadata({
                name: "Food",
                description: "",
                metadataURL: "https://meta/m.json",
                royaltyBps: 0,
                royaltyReceiver: owner,
                usageLimit: 1
            })
        );
        uint256 id = target.mintPrintEdition(to, mid, printNumber, "https://meta/p.json");
        vm.stopPrank();
        return id;
    }

    // ---------- adoptPet ----------

    function testAdoptPetBurnsAndMints() public {
        vm.expectEmit(true, true, false, false);
        emit PetAdopted(user, address(nft), printId, 0);

        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "https://meta/pet-1.json");

        // 商品已销毁
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, printId)
        );
        nft.ownerOf(printId);

        // 宠物已铸造
        assertEq(pet.ownerOf(petId), user);
        assertEq(pet.petLevel(petId), 0);
        assertEq(pet.tokenURI(petId), "https://meta/pet-1.json");
        assertEq(pet.sourceContract(petId), address(nft));
        assertEq(pet.sourceTokenId(petId), printId);
    }

    function testAdoptPetWorksOnTransferLockedToken() public {
        // 本地生活凭证永久锁定，领养必须仍可销毁
        vm.prank(owner);
        nft.lockTransfer(printId);

        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "url");
        assertEq(pet.ownerOf(petId), user);
    }

    function testAdoptPetRevertsForNonOperator() public {
        vm.prank(stranger);
        vm.expectRevert("Not pet operator");
        pet.adoptPet(address(nft), printId, user, "url");
    }

    function testAdoptPetRevertsOnOwnerMismatch() public {
        vm.prank(petOperator);
        vm.expectRevert("Not token owner");
        pet.adoptPet(address(nft), printId, stranger, "url");
    }

    function testAdoptPetRevertsOnMaster() public {
        vm.prank(petOperator);
        vm.expectRevert("Cannot burn master");
        pet.adoptPet(address(nft), masterId, owner, "url");
    }

    function testPetBurnOnlyCallableByPetSystem() public {
        vm.prank(stranger);
        vm.expectRevert("Not pet system");
        nft.petBurn(printId);

        // owner 也不行（必须走 WhimPet 合约）
        vm.prank(owner);
        vm.expectRevert("Not pet system");
        nft.petBurn(printId);
    }

    function testPetBurnBlockedWhenPetSystemUnset() public {
        NFTManager fresh = _deployNFTManager();
        uint256 id = _mintPrintTo(fresh, user, 1);
        // petSystem 未设置时领养应失败
        vm.prank(petOperator);
        vm.expectRevert();
        pet.adoptPet(address(fresh), id, user, "url");
    }

    function testPetIsSoulbound() public {
        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "url");

        vm.prank(user);
        vm.expectRevert("Soulbound: transfers disabled");
        pet.transferFrom(user, stranger, petId);
    }

    function testTransfersCanBeEnabledLater() public {
        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "url");

        vm.prank(owner);
        pet.setTransfersEnabled(true);

        vm.prank(user);
        pet.transferFrom(user, stranger, petId);
        assertEq(pet.ownerOf(petId), stranger);
    }

    // ---------- feedPet ----------

    function testFeedPetBurnsAndLevelsUp() public {
        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "https://meta/pet-v0.json");

        uint256 food = _mintPrintTo(nft, user, 2);

        vm.expectEmit(true, true, false, true);
        emit PetEvolved(petId, address(nft), food, 1);
        vm.expectEmit(false, false, false, true);
        emit MetadataUpdate(petId);

        vm.prank(petOperator);
        pet.feedPet(address(nft), food, petId, "https://meta/pet-v1.json");

        assertEq(pet.petLevel(petId), 1);
        assertEq(pet.tokenURI(petId), "https://meta/pet-v1.json");
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, food)
        );
        nft.ownerOf(food);
    }

    function testFeedPetAcrossDifferentNFTManagers() public {
        // 领养烧 nft 上的商品，喂养烧 nft2 上的商品 —— 跨合约
        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "url-v0");

        uint256 foodOnNft2 = _mintPrintTo(nft2, user, 1);

        vm.prank(petOperator);
        pet.feedPet(address(nft2), foodOnNft2, petId, "url-v1");

        assertEq(pet.petLevel(petId), 1);
    }

    function testFeedPetRevertsOnOwnerMismatch() public {
        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "url");

        uint256 strangerFood = _mintPrintTo(nft, stranger, 2);

        vm.prank(petOperator);
        vm.expectRevert("Owner mismatch");
        pet.feedPet(address(nft), strangerFood, petId, "url2");
    }

    function testFeedPetRevertsOnNonexistentPet() public {
        uint256 food = _mintPrintTo(nft, user, 2);
        vm.prank(petOperator);
        vm.expectRevert();
        pet.feedPet(address(nft), food, 999, "url");
    }

    // ---------- setPetMetadataURL ----------

    function testSetPetMetadataURL() public {
        vm.prank(petOperator);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "url-v0");

        vm.prank(petOperator);
        pet.setPetMetadataURL(petId, "url-skin");
        assertEq(pet.tokenURI(petId), "url-skin");

        vm.prank(stranger);
        vm.expectRevert("Not pet operator");
        pet.setPetMetadataURL(petId, "url-x");
    }

    // ---------- misc ----------

    function testSupportsERC4906() public view {
        assertTrue(pet.supportsInterface(bytes4(0x49064906)));
    }

    function testOwnerCanActAsPetOperator() public {
        vm.prank(owner);
        uint256 petId = pet.adoptPet(address(nft), printId, user, "url");
        assertEq(pet.ownerOf(petId), user);
    }

    function testPausedBlocksPetOps() public {
        vm.prank(owner);
        pet.pause();

        vm.prank(petOperator);
        vm.expectRevert();
        pet.adoptPet(address(nft), printId, user, "url");
    }

    function testNFTManagerPausedBlocksBurn() public {
        vm.prank(owner);
        nft.pause();

        vm.prank(petOperator);
        vm.expectRevert();
        pet.adoptPet(address(nft), printId, user, "url");
    }
}
