// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {NFTManager} from "../src/token/NFTManager.sol";
import {Chain1520Config} from "./Chain1520Config.sol";

/// @notice Batch-upgrade NFTManager proxies to the WhimPet-capable implementation
///         and configure petSystem when WHIMPET_ADDR is set (default: Chain1520Config.WHIMPET).
///
/// Env vars:
///   PRIVATE_KEY_WHIM  — ProxyAdmin owner signer
///   PROXIES           — comma-separated proxy addresses
///   IMPL_ADDR         — (optional) defaults to Chain1520Config.NFT_MANAGER_IMPL
///   WHIMPET_ADDR      — (optional) defaults to Chain1520Config.WHIMPET; set to address(0) to skip setPetSystem
contract UpgradeAllNFTManagers is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_WHIM");
        address implAddr = vm.envOr(
            "IMPL_ADDR",
            Chain1520Config.NFT_MANAGER_IMPL
        );
        address whimPetAddr = vm.envOr(
            "WHIMPET_ADDR",
            Chain1520Config.WHIMPET
        );
        address[] memory proxies = vm.envAddress("PROXIES", ",");

        require(proxies.length > 0, "PROXIES env is empty");
        require(implAddr.code.length > 0, "IMPL_ADDR has no code");

        address signer = vm.addr(privateKey);
        console.log("Signer:", signer);
        console.log("New implementation:", implAddr);
        console.log("WhimPet:", whimPetAddr);
        console.log("Proxies to upgrade:", proxies.length);

        vm.startBroadcast(privateKey);

        for (uint256 i = 0; i < proxies.length; i++) {
            address proxy = proxies[i];
            address adminAddr = _getProxyAdmin(proxy);
            ProxyAdmin admin = ProxyAdmin(adminAddr);

            console.log("--------");
            console.log("Proxy:", proxy);
            console.log("ProxyAdmin:", adminAddr);

            admin.upgradeAndCall(
                ITransparentUpgradeableProxy(proxy),
                implAddr,
                ""
            );

            if (whimPetAddr != address(0)) {
                require(whimPetAddr.code.length > 0, "WHIMPET_ADDR has no code");
                NFTManager(payable(proxy)).setPetSystem(whimPetAddr);
                console.log("petSystem:", NFTManager(payable(proxy)).petSystem());
            }

            console.log("Upgraded OK");
        }

        vm.stopBroadcast();
        console.log("All upgrades broadcast.");
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
