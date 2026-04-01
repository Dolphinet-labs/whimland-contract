// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "./utils/EmptyContract.sol";
import {WhimLandMarket} from "../src/token/WhimLandMarket.sol";

contract DeployWhimLandMarket is Script {
    EmptyContract public emptyContract;
    ProxyAdmin public whimLandMarketProxyAdmin;
    WhimLandMarket public whimLandMarket;
    WhimLandMarket public whimLandMarketImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_WHIM");
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address deployerAddress = vm.addr(deployerPrivateKey);

        // NFTManager 代理地址
        address nftManagerProxy = address(
            0xFe9a5B0c7168d37421A4b06476f88c9bae56b699
        );

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();

        TransparentUpgradeableProxy proxyWhimLandMarket = new TransparentUpgradeableProxy(
                address(emptyContract),
                deployerAddress,
                ""
            );
        whimLandMarket = WhimLandMarket(payable(address(proxyWhimLandMarket)));
        whimLandMarketImplementation = new WhimLandMarket();
        whimLandMarketProxyAdmin = ProxyAdmin(
            getProxyAdminAddress(address(proxyWhimLandMarket))
        );

        whimLandMarketProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(whimLandMarket)),
            address(whimLandMarketImplementation),
            abi.encodeWithSelector(
                WhimLandMarket.initialize.selector,
                nftManagerProxy,
                deployerAddress
            )
        );

        console.log(
            "deploy proxyWhimLandMarket:",
            address(proxyWhimLandMarket)
        );
        console.log(
            "Implementation WhimLandMarket:",
            address(whimLandMarketImplementation)
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

/**
 * 
 To deploy and verify:

    NFT_MANAGER_PROXY=<your_nft_manager_proxy_address> \
    forge script script/deployWhimLandMarket.s.sol   --rpc-url $DOL_TESTNET_RPC_URL   --private-key $PRIVATE_KEY_WHIM 
    --broadcast   --verify   --verifier blockscout   --verifier-url https://explorer-testnet.dolphinode.world/api/
 */
