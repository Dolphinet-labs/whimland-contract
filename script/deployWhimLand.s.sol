// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "./utils/EmptyContract.sol";
import {EmptyContract} from "./utils/EmptyContract.sol";
import {WhimLandOrderBook} from "../src/WhimLandOrderBook.sol";
import {WhimLandVault} from "../src/WhimLandVault.sol";

contract DeployerCpChainBridge is Script {
    EmptyContract public emptyContract;
    ProxyAdmin public whimLandVaultProxyAdmin;
    ProxyAdmin public whimLandOrderBookProxyAdmin;
    WhimLandVault public whimLandVault;
    WhimLandVault public whimLandVaultImplementation;
    WhimLandOrderBook public whimLandOrderBook;
    WhimLandOrderBook public whimLandOrderBookImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_WHIM");
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();

        TransparentUpgradeableProxy proxyWhimLandVault = new TransparentUpgradeableProxy(
                address(emptyContract),
                deployerAddress,
                ""
            );
        whimLandVault = WhimLandVault(payable(address(proxyWhimLandVault)));
        whimLandVaultImplementation = new WhimLandVault();
        whimLandVaultProxyAdmin = ProxyAdmin(
            getProxyAdminAddress(address(proxyWhimLandVault))
        );

        TransparentUpgradeableProxy proxyWhimLandOrderBook = new TransparentUpgradeableProxy(
                address(emptyContract),
                deployerAddress,
                ""
            );
        whimLandOrderBook = WhimLandOrderBook(
            payable(address(proxyWhimLandOrderBook))
        );
        whimLandOrderBookImplementation = new WhimLandOrderBook();
        whimLandOrderBookProxyAdmin = ProxyAdmin(
            getProxyAdminAddress(address(proxyWhimLandOrderBook))
        );

        whimLandVaultProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(whimLandVault)),
            address(whimLandVaultImplementation),
            abi.encodeWithSelector(
                WhimLandVault.initialize.selector,
                deployerAddress,
                address(whimLandOrderBook)
            )
        );
        whimLandOrderBookProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(whimLandOrderBook)),
            address(whimLandOrderBookImplementation),
            abi.encodeWithSelector(
                WhimLandOrderBook.initialize.selector,
                100,
                address(whimLandVault),
                "whimLand OrderBook",
                "1.0",
                deployerAddress
            )
        );

        console.log("deploy proxyWhimLandVault:", address(proxyWhimLandVault));
        console.log(
            "Implementation WhimLandVault:",
            address(whimLandVaultImplementation)
        );
        console.log(
            "deploy proxyWhimLandOrderBook:",
            address(proxyWhimLandOrderBook)
        );
        console.log(
            "Implementation WhimLandOrderBook:",
            address(whimLandOrderBookImplementation)
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
To deploy and verify:

    forge script script/deployWhimLand.s.sol   --rpc-url $DOL_TESTNET_RPC_URL   --private-key $PRIVATE_KEY_WHIM   
    --broadcast   --verify   --verifier blockscout   --verifier-url https://explorer-testnet.dolphinode.world/api/
 */
