// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "./utils/EmptyContract.sol";
import {EmptyContract} from "./utils/EmptyContract.sol";
import {NFTAuction} from "../src/Auction.sol";

contract DeployerCpChainBridge is Script {
    EmptyContract public emptyContract;
    ProxyAdmin public nftAuctionProxyAdmin;
    NFTAuction public nftAuction;
    NFTAuction public nftAuctionImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_WHIM");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();

        TransparentUpgradeableProxy proxyAuction = new TransparentUpgradeableProxy(
                address(emptyContract),
                deployerAddress,
                ""
            );
        nftAuction = NFTAuction(payable(address(proxyAuction)));
        nftAuctionImplementation = new NFTAuction();
        nftAuctionProxyAdmin = ProxyAdmin(
            getProxyAdminAddress(address(proxyAuction))
        );

        nftAuctionProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(nftAuction)),
            address(nftAuctionImplementation),
            abi.encodeWithSelector(
                NFTAuction.initialize.selector,
                deployerAddress,
                500
            )
        );

        console.log("deploy proxyAuction:", address(proxyAuction));
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
