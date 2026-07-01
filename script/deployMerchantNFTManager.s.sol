// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {EmptyContract} from "./utils/EmptyContract.sol";
import {NFTManager} from "../src/token/NFTManager.sol";
import {WhimLandOrderBook} from "../src/WhimLandOrderBook.sol";
import {Chain1520Config} from "./Chain1520Config.sol";

/// @notice Deploy one merchant NFTManager from env vars NFT_COLLECTION_NAME / NFT_COLLECTION_SYMBOL.
///         After deploy: transferOwnership -> platform treasury, whitelist on OrderBook.
///
/// Required env:
///   PRIVATE_KEY_WHIM              — deployer (ProxyAdmin owner)
///   NFT_COLLECTION_NAME           — ERC721 collection name
///   NFT_COLLECTION_SYMBOL         — ERC721 symbol
///
/// Optional env:
///   ORDERBOOK_OWNER_PRIVATE_KEY   — OrderBook owner signer (defaults to PRIVATE_KEY_WHIM)
///   NFT_MANAGER_NEW_OWNER         — new owner after deploy (defaults to platform treasury)
///   ORDER_BOOK_PROXY              — OrderBook proxy on chain 1520
///   VRF_POD_ADDRESS               — VRF pod for mint randomness
///   PLATFORM_MINTER_ADDRESS       — if set, whitelisted on NFTManager before ownership transfer
///   NFT_IMPL_ADDR                   — canonical NFTManager impl (default: Chain1520Config.NFT_MANAGER_IMPL)
///   WHIMPET_ADDR                    — WhimPet proxy (default: Chain1520Config.WHIMPET)
contract DeployMerchantNFTManager is Script {
    address internal constant DEFAULT_ORDER_BOOK =
        0x7eEe27eFE34d04048F7e0E4230172AF6D6E5A986;
    address internal constant DEFAULT_VRF_POD =
        0x2ECA23AeE3F5CbF87eaF33857797506c8A6A6d94;
    address internal constant DEFAULT_NEW_OWNER =
        0x2162d8b4662D73Ca296BEe28BFE02f6E2527f6b4;

    uint256 internal constant MAX_SUPPLY = 1_000_000;
    string internal constant BASE_URI =
        "https://whim.land/api/v1/nft/{id}";

    function run() external {
        uint256 deployKey = vm.envUint("PRIVATE_KEY_WHIM");
        uint256 orderBookKey = vm.envOr(
            "ORDERBOOK_OWNER_PRIVATE_KEY",
            deployKey
        );

        string memory collectionName = vm.envString("NFT_COLLECTION_NAME");
        string memory collectionSymbol = vm.envString("NFT_COLLECTION_SYMBOL");

        address newOwner = vm.envOr(
            "NFT_MANAGER_NEW_OWNER",
            DEFAULT_NEW_OWNER
        );
        address orderBookProxy = vm.envOr(
            "ORDER_BOOK_PROXY",
            DEFAULT_ORDER_BOOK
        );
        address vrfPod = vm.envOr("VRF_POD_ADDRESS", DEFAULT_VRF_POD);
        address nftImplAddr = vm.envOr(
            "NFT_IMPL_ADDR",
            Chain1520Config.NFT_MANAGER_IMPL
        );
        address whimPetAddr = vm.envOr(
            "WHIMPET_ADDR",
            Chain1520Config.WHIMPET
        );

        require(nftImplAddr.code.length > 0, "NFT_IMPL_ADDR has no code");
        require(whimPetAddr.code.length > 0, "WHIMPET_ADDR has no code");

        address deployer = vm.addr(deployKey);
        address orderBookOwner = vm.addr(orderBookKey);

        console.log("Deployer:", deployer);
        console.log("OrderBook owner signer:", orderBookOwner);
        console.log("New NFTManager owner:", newOwner);
        console.log("OrderBook proxy:", orderBookProxy);
        console.log("VRF pod:", vrfPod);
        console.log("Name:", collectionName);
        console.log("Symbol:", collectionSymbol);
        console.log("NFT implementation:", nftImplAddr);
        console.log("WhimPet:", whimPetAddr);

        vm.startBroadcast(deployKey);

        EmptyContract emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyNftManager =
            new TransparentUpgradeableProxy(
                address(emptyContract),
                deployer,
                ""
            );

        NFTManager nftManager = NFTManager(payable(address(proxyNftManager)));
        ProxyAdmin nftManagerProxyAdmin = ProxyAdmin(
            _getProxyAdminAddress(address(proxyNftManager))
        );

        nftManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(nftManager)),
            nftImplAddr,
            abi.encodeWithSelector(
                NFTManager.initialize.selector,
                collectionName,
                collectionSymbol,
                MAX_SUPPLY,
                BASE_URI,
                deployer,
                vrfPod
            )
        );

        address proxyAddress = address(proxyNftManager);
        console.log("proxyNftManager:", proxyAddress);
        console.log("implementation:", nftImplAddr);
        console.log("proxyAdmin:", address(nftManagerProxyAdmin));

        address minter = vm.envOr("PLATFORM_MINTER_ADDRESS", address(0));
        if (minter != address(0)) {
            nftManager.setWhiteList(minter, true);
            console.log("Whitelisted minter:", minter);
        }

        nftManager.setPetSystem(whimPetAddr);
        console.log("petSystem:", nftManager.petSystem());

        nftManager.transferOwnership(newOwner);
        console.log("Ownership transferred to:", newOwner);

        vm.stopBroadcast();

        vm.startBroadcast(orderBookKey);
        WhimLandOrderBook(payable(orderBookProxy)).setWhitelistedCollection(
            proxyAddress,
            true
        );
        console.log("OrderBook collection whitelisted:", proxyAddress);
        vm.stopBroadcast();
    }

    function _getProxyAdminAddress(
        address proxy
    ) internal view returns (address) {
        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
