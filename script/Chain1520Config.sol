// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Canonical on-chain addresses for Dolphinet (chain 1520).
library Chain1520Config {
    address internal constant WHIMPET =
        0xFf66ebBEB2dA357b8f21E36c89340b5914dc7984;
    address internal constant NFT_MANAGER_IMPL =
        0xe996AD9579C0EBbDE916A37F2381BB2099f5467E;
    address internal constant MAIN_NFT_MANAGER =
        0x8Ba567897F277a14c714998C3c15E9dB99FEceA1;

    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
}
