// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MiniSavingAccount} from "../src/MiniSavingAccount.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new MiniSavingAccount();

        vm.stopBroadcast();
    }
}
