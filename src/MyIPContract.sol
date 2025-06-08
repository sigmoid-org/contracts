// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@storyprotocol/core/contracts/IPAssetRegistry.sol";

contract MyIPContract {
    IPAssetRegistry public registry;
    
    constructor(address _registry) {
        registry = IPAssetRegistry(_registry);
    }
}
