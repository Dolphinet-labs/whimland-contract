// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "./utils/EmptyContract.sol";
import {NFTManager} from "../src/token/NFTManager.sol";

contract UpgradeNFTManager is Script {
    ProxyAdmin public nftManagerProxyAdmin;
    address public constant NFT_MANAGER_PROXY_ADDRESS =
        0x0C62111cdb7e245CF62f6B8b0ec2100DB4c39C29;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_WHIM");
        vm.startBroadcast(privateKey);

        // Deploy the new version of the NFTManager contract
        NFTManager newNFTManager = new NFTManager();

        nftManagerProxyAdmin = ProxyAdmin(
            getProxyAdminAddress(NFT_MANAGER_PROXY_ADDRESS)
        );

        // Perform the upgrade
        nftManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(NFT_MANAGER_PROXY_ADDRESS)),
            address(newNFTManager),
            ""
        );
        console.log(
            "NFTManager upgraded successfully to new implementation:",
            address(newNFTManager)
        );

        vm.stopBroadcast();
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
