// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {NFTManager} from "../src/token/NFTManager.sol";
import {WhimPet} from "../src/token/WhimPet.sol";

/// @notice AI 宠物系统部署脚本（双钥匙）：
///   - DEPLOYER_KEY（sequencer）：部署 WhimPet（impl+proxy）、新 NFTManager impl、setPetOperator
///   - OWNER_KEY（NFTManager/ProxyAdmin owner）：升级所有 NFTManager proxy + setPetSystem
///
/// Env vars:
///   - DEPLOYER_KEY       — WhimPet 部署者（也是 WhimPet owner）
///   - OWNER_KEY          — 各 NFTManager ProxyAdmin 与合约的 owner
///   - PROXIES            — 逗号分隔的 NFTManager proxy 地址列表
///   - PET_OPERATOR       — 平台宠物操作钱包（后端热钱包）
///   - NFT_IMPL_ADDR      — (可选) 复用已部署的 NFTManager implementation
///   - WHIMPET_ADDR       — (可选) 复用已部署的 WhimPet proxy
///
///   forge script script/deployWhimPet.s.sol --rpc-url $RPC_URL --broadcast
contract DeployWhimPet is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        uint256 ownerKey = vm.envUint("OWNER_KEY");
        address[] memory proxies = vm.envAddress("PROXIES", ",");
        address petOperator = vm.envAddress("PET_OPERATOR");
        address nftImplAddr = vm.envOr("NFT_IMPL_ADDR", address(0));
        address whimPetAddr = vm.envOr("WHIMPET_ADDR", address(0));

        require(proxies.length > 0, "PROXIES env is empty");
        require(petOperator != address(0), "PET_OPERATOR is zero");

        address deployer = vm.addr(deployerKey);
        address owner = vm.addr(ownerKey);
        console.log("Deployer (WhimPet owner):", deployer);
        console.log("NFTManager owner:", owner);
        console.log("Pet operator:", petOperator);

        // ============ 阶段 1：deployer 部署 ============
        vm.startBroadcast(deployerKey);

        WhimPet whimPet;
        if (whimPetAddr == address(0)) {
            WhimPet petImpl = new WhimPet();
            TransparentUpgradeableProxy petProxy = new TransparentUpgradeableProxy(
                address(petImpl),
                deployer, // WhimPet 自己的 ProxyAdmin owner
                abi.encodeCall(WhimPet.initialize, ("Whimland Pets", "WHIMPET", deployer))
            );
            whimPet = WhimPet(address(petProxy));
            console.log("WhimPet implementation:", address(petImpl));
            console.log("WhimPet proxy:", address(whimPet));
        } else {
            whimPet = WhimPet(whimPetAddr);
            console.log("Reusing WhimPet proxy:", whimPetAddr);
        }

        if (nftImplAddr == address(0)) {
            nftImplAddr = address(new NFTManager());
            console.log("Deployed NFTManager implementation:", nftImplAddr);
        } else {
            require(nftImplAddr.code.length > 0, "NFT_IMPL_ADDR has no code");
            console.log("Reusing NFTManager implementation:", nftImplAddr);
        }

        if (whimPet.petOperator() != petOperator) {
            whimPet.setPetOperator(petOperator);
        }
        console.log("WhimPet.petOperator:", whimPet.petOperator());

        vm.stopBroadcast();

        // ============ 阶段 2：owner 升级 NFTManager + setPetSystem ============
        vm.startBroadcast(ownerKey);

        for (uint256 i = 0; i < proxies.length; i++) {
            address proxy = proxies[i];
            address adminAddr = _getProxyAdmin(proxy);
            ProxyAdmin admin = ProxyAdmin(adminAddr);

            console.log("--------");
            console.log("Proxy:", proxy);
            console.log("ProxyAdmin:", adminAddr);

            admin.upgradeAndCall(
                ITransparentUpgradeableProxy(proxy),
                nftImplAddr,
                ""
            );

            NFTManager(payable(proxy)).setPetSystem(address(whimPet));
            console.log("Upgraded + petSystem set:", NFTManager(payable(proxy)).petSystem());
        }

        vm.stopBroadcast();
        console.log("Done. WhimPet:", address(whimPet));
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
