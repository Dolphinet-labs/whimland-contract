// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/// @notice Batch-upgrades multiple NFTManager TransparentUpgradeableProxy instances
///         on chain 1520 to the already-deployed new implementation at
///         0x916498207231F5171f7BeBB312a3e81D6a7aDfE0 (which exposes
///         mintPrintEditionAndLock + transferLocked view).
/// Env vars required:
///   - PRIVATE_KEY_WHIM  (hex, with or without 0x prefix) — signer for the ProxyAdmin.owner()
///   - IMPL_ADDR         (optional) — defaults to 0x916498207231F5171f7BeBB312a3e81D6a7aDfE0
///   - PROXIES           — comma-separated list of proxy addresses to upgrade
contract UpgradeAllNFTManagers is Script {
    address public constant DEFAULT_IMPL = 0x916498207231F5171f7BeBB312a3e81D6a7aDfE0;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY_WHIM");
        address implAddr = vm.envOr("IMPL_ADDR", DEFAULT_IMPL);
        address[] memory proxies = vm.envAddress("PROXIES", ",");

        require(proxies.length > 0, "PROXIES env is empty");
        require(implAddr.code.length > 0, "IMPL_ADDR has no code");

        address signer = vm.addr(privateKey);
        console.log("Signer:", signer);
        console.log("New implementation:", implAddr);
        console.log("Proxies to upgrade:", proxies.length);

        vm.startBroadcast(privateKey);

        for (uint256 i = 0; i < proxies.length; i++) {
            address proxy = proxies[i];
            address adminAddr = _getProxyAdmin(proxy);
            ProxyAdmin admin = ProxyAdmin(adminAddr);

            console.log("--------");
            console.log("Proxy:", proxy);
            console.log("ProxyAdmin:", adminAddr);
            console.log("ProxyAdmin.owner():", admin.owner());

            admin.upgradeAndCall(
                ITransparentUpgradeableProxy(proxy),
                implAddr,
                ""
            );

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
