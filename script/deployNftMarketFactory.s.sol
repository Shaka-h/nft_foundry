// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {NFTFactory} from "../src/nftFactory.sol";


contract DeploynftFactory is Script {
    function run() external returns (NFTFactory){
        vm.startBroadcast();

        NFTFactory nftContract = new NFTFactory();

        vm.stopBroadcast();
        
        return nftContract;
    }
}

