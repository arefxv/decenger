// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Decenger} from "src/Decenger.sol";

contract DeployDecenger is Script{

    function run() external returns(Decenger){
        return deployDecenger();
    }

    function deployDecenger() public returns (Decenger){
        vm.startBroadcast();
        Decenger decenger = new Decenger();
        vm.stopBroadcast();

        return(decenger);
    }
}