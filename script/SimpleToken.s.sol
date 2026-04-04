// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/SimpleToken.sol";

contract DeploySimpleToken is Script {
    function run() external {
        vm.startBroadcast();
        new SimpleToken();
        vm.stopBroadcast();
    }
}