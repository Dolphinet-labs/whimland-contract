// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {NFTManager} from "../src/token/NFTManager.sol";
import {Chain1520Config} from "./Chain1520Config.sol";

/// @notice Idempotently upgrade NFTManager proxies to the WhimPet-capable implementation
///         and call setPetSystem(WhimPet) on each.
///
/// Merchant deploys often split ownership:
///   - ProxyAdmin owner (deployer / sequencer) → upgradeAndCall
///   - NFTManager owner (platform treasury) → setPetSystem
///
/// Required env (at least one key pair):
///   PROXY_ADMIN_KEY        — ProxyAdmin owner signer (upgrade)
///   NFT_MANAGER_OWNER_KEY  — NFTManager owner signer (setPetSystem)
/// Legacy fallback: PRIVATE_KEY_WHIM used for both when split keys are omitted.
///
/// Optional env:
///   PROXIES / PROXIES_FILE / NFT_IMPL_ADDR / WHIMPET_ADDR
contract UpgradeNFTManagersForWhimPet is Script {
    struct ProxyPlan {
        address proxy;
        bool needsUpgrade;
        bool needsPetSystem;
    }

    uint256 internal candidateKeyCount;
    uint256[8] internal candidateKeys;
    address[8] internal candidateSigners;

    function _loadCandidateKeys() internal {
        string memory raw = vm.envString("PROXY_ADMIN_KEYS");
        bytes memory b = bytes(raw);
        uint256 start;
        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == bytes1(",")) {
                if (i > start) {
                    require(candidateKeyCount < 8, "Too many PROXY_ADMIN_KEYS");
                    uint256 key = vm.parseUint(string(_slice(b, start, i)));
                    candidateKeys[candidateKeyCount] = key;
                    candidateSigners[candidateKeyCount] = vm.addr(key);
                    candidateKeyCount++;
                }
                start = i + 1;
            }
        }
        require(candidateKeyCount > 0, "PROXY_ADMIN_KEYS empty");
    }

    function _slice(
        bytes memory b,
        uint256 start,
        uint256 end
    ) internal pure returns (bytes memory out) {
        out = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = b[i];
        }
    }

    function _keyForOwner(address owner) internal view returns (uint256) {
        for (uint256 i = 0; i < candidateKeyCount; i++) {
            if (candidateSigners[i] == owner) {
                return candidateKeys[i];
            }
        }
        revert(string(abi.encodePacked("No PROXY_ADMIN_KEYS entry for owner ", vm.toString(owner))));
    }

    function run() external {
        uint256 proxyAdminKey = _resolveKey("PROXY_ADMIN_KEY");
        uint256 nftOwnerKey = _resolveKey("NFT_MANAGER_OWNER_KEY");
        _loadCandidateKeys();

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

        address[] memory proxies = _loadProxies();
        require(proxies.length > 0, "No proxies to upgrade");

        console.log("ProxyAdmin signer (fallback):", vm.addr(proxyAdminKey));
        console.log("NFTManager owner signer:", vm.addr(nftOwnerKey));
        console.log("Target implementation:", nftImplAddr);
        console.log("WhimPet:", whimPetAddr);
        console.log("Proxies:", proxies.length);

        ProxyPlan[] memory plans = new ProxyPlan[](proxies.length);
        uint256 upgradeCount;
        uint256 petSystemCount;
        uint256 skipped;

        for (uint256 i = 0; i < proxies.length; i++) {
            address proxy = proxies[i];
            if (proxy.code.length == 0) {
                console.log("SKIP (no code):", proxy);
                skipped++;
                continue;
            }

            address currentImpl = _implementation(proxy);
            (address currentPetSystem, bool petSystemSupported) = _currentPetSystem(
                proxy
            );

            bool needsUpgrade = currentImpl != nftImplAddr;
            bool needsPetSystem = !petSystemSupported ||
                currentPetSystem != whimPetAddr;

            console.log("--------");
            console.log("Proxy:", proxy);
            console.log("Current impl:", currentImpl);
            console.log(
                "Current petSystem:",
                petSystemSupported ? currentPetSystem : address(0)
            );

            if (!needsUpgrade && !needsPetSystem) {
                console.log("Already up to date");
                skipped++;
                continue;
            }

            plans[i] = ProxyPlan({
                proxy: proxy,
                needsUpgrade: needsUpgrade,
                needsPetSystem: needsPetSystem
            });
            if (needsUpgrade) upgradeCount++;
            if (needsPetSystem) petSystemCount++;
        }

        uint256 upgraded;
        if (upgradeCount > 0) {
            console.log("== Phase 1: upgrade implementation ==");
            for (uint256 i = 0; i < plans.length; i++) {
                if (!plans[i].needsUpgrade) continue;
                address proxy = plans[i].proxy;
                address adminAddr = _getProxyAdmin(proxy);
                address adminOwner = ProxyAdmin(adminAddr).owner();
                uint256 upgradeKey = _keyForOwner(adminOwner);
                vm.broadcast(upgradeKey);
                ProxyAdmin(adminAddr).upgradeAndCall(
                    ITransparentUpgradeableProxy(proxy),
                    nftImplAddr,
                    ""
                );
                upgraded++;
                console.log("Upgraded:", proxy, "signer:", vm.addr(upgradeKey));
            }
        }

        uint256 petSystemSet;
        if (petSystemCount > 0) {
            console.log("== Phase 2: setPetSystem ==");
            for (uint256 i = 0; i < plans.length; i++) {
                if (!plans[i].needsPetSystem) continue;
                address proxy = plans[i].proxy;
                vm.broadcast(nftOwnerKey);
                NFTManager(payable(proxy)).setPetSystem(whimPetAddr);
                petSystemSet++;
                console.log(
                    "petSystem set:",
                    proxy,
                    NFTManager(payable(proxy)).petSystem()
                );
            }
        }

        console.log("Done. upgraded:", upgraded);
        console.log("petSystem configured:", petSystemSet);
        console.log("skipped:", skipped);
    }

    function _resolveKey(string memory name) internal view returns (uint256) {
        string memory val = vm.envOr(name, string(""));
        if (bytes(val).length > 0) {
            return vm.envUint(name);
        }
        return vm.envUint("PRIVATE_KEY_WHIM");
    }

    function _loadProxies() internal view returns (address[] memory) {
        string memory proxiesEnv = vm.envOr("PROXIES", string(""));
        if (bytes(proxiesEnv).length > 0) {
            return vm.envAddress("PROXIES", ",");
        }

        string memory filePath = vm.envOr(
            "PROXIES_FILE",
            string("script/data/nft-manager-proxies-1520.txt")
        );
        string memory content = vm.readFile(filePath);
        return _parseAddressLines(content);
    }

    function _parseAddressLines(
        string memory content
    ) internal view returns (address[] memory) {
        bytes memory b = bytes(content);
        uint256 count;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == bytes1("\n")) count++;
        }
        if (b.length > 0 && b[b.length - 1] != bytes1("\n")) count++;

        address[] memory tmp = new address[](count);
        uint256 idx;
        uint256 lineStart;

        for (uint256 i = 0; i <= b.length; i++) {
            if (i == b.length || b[i] == bytes1("\n")) {
                if (i > lineStart) {
                    address addr = _parseLine(content, lineStart, i);
                    if (addr != address(0)) {
                        tmp[idx++] = addr;
                    }
                }
                lineStart = i + 1;
            }
        }

        address[] memory out = new address[](idx);
        for (uint256 j = 0; j < idx; j++) {
            out[j] = tmp[j];
        }
        return out;
    }

    function _parseLine(
        string memory content,
        uint256 start,
        uint256 end
    ) internal view returns (address) {
        bytes memory lineBytes = new bytes(end - start);
        bytes memory src = bytes(content);
        for (uint256 i = start; i < end; i++) {
            lineBytes[i - start] = src[i];
        }
        string memory line = string(lineBytes);
        bytes memory trimmed = bytes(_trim(line));
        if (trimmed.length == 0) return address(0);
        if (trimmed[0] == bytes1("#")) return address(0);
        return vm.parseAddress(string(trimmed));
    }

    function _trim(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        uint256 start;
        while (start < b.length && (b[start] == bytes1(" ") || b[start] == bytes1("\r"))) {
            start++;
        }
        uint256 end = b.length;
        while (end > start && (b[end - 1] == bytes1(" ") || b[end - 1] == bytes1("\r"))) {
            end--;
        }
        bytes memory out = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            out[i - start] = b[i];
        }
        return string(out);
    }

    function _implementation(address proxy) internal view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        vm.load(proxy, Chain1520Config.IMPLEMENTATION_SLOT)
                    )
                )
            );
    }

    function _currentPetSystem(
        address proxy
    ) internal view returns (address petSystem, bool supported) {
        try NFTManager(payable(proxy)).petSystem() returns (address addr) {
            return (addr, true);
        } catch {
            return (address(0), false);
        }
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
