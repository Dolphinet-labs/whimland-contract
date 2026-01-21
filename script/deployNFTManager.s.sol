// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "./utils/EmptyContract.sol";
import {NFTManager} from "../src/token/NFTManager.sol";

contract DeployerCpChainBridge is Script {
    EmptyContract public emptyContract;
    ProxyAdmin public nftManagerProxyAdmin;
    NFTManager public nftManager;
    NFTManager public nftManagerImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_WHIM");
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();

        TransparentUpgradeableProxy proxyNftManager = new TransparentUpgradeableProxy(
                address(emptyContract),
                deployerAddress,
                ""
            );
        nftManager = NFTManager(payable(address(proxyNftManager)));
        nftManagerImplementation = new NFTManager();
        nftManagerProxyAdmin = ProxyAdmin(
            getProxyAdminAddress(address(proxyNftManager))
        );

        nftManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(nftManager)),
            address(nftManagerImplementation),
            abi.encodeWithSelector(
                NFTManager.initialize.selector,
                "Whimland_NFT",
                "whim",
                100,
                "https://whimlandnft.com/api/v1/nft/{id}",
                deployerAddress,
                deployerAddress
            )
        );

        console.log("deploy proxyNftManager:", address(proxyNftManager));
        console.log(
            "Implementation NFTManager:",
            address(nftManagerImplementation)
        );

        // mint a master NFT
        NFTManager.NFTMetadata memory nftMetadata = NFTManager.NFTMetadata({
            name: "Master NFT",
            description: "This is the master NFT for exclusive access.",
            metadataURL: "https://masternft.example.com",
            royaltyBps: 500,
            royaltyReceiver: deployerAddress,
            usageLimit: 10
        });
        uint256 token_id = nftManager.mintMaster(
            address(0x2aa76c12368Bc8aEF4190400Ef4Af19fd0b4247c),
            nftMetadata
        );
        console.log("Minted Master NFT with token ID:", token_id);

        // mint print editions for the master NFT
        nftManager.mintPrintEdition(
            address(0x2aa76c12368Bc8aEF4190400Ef4Af19fd0b4247c),
            token_id,
            77,
            ""
        );
        console.log("Minted #77 Print Editions for Master NFT ID:", token_id);

        // set editor for the NFTManager
        nftManager.setEditer(
            address(0x2aa76c12368Bc8aEF4190400Ef4Af19fd0b4247c),
            true,
            0
        );
    }

    function getProxyAdminAddress(
        address proxy
    ) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}

/**
 * 
 To deploy and verify:

    forge script script/deployNFTManager.s.sol   --rpc-url $DOL_TESTNET_RPC_URL   --private-key $PRIVATE_KEY_WHIM 
    --broadcast   --verify   --verifier blockscout   --verifier-url https://explorer-testnet.dolphinode.world/api/
 */
