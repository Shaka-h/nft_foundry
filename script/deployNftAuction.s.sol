// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {NFTMarket} from "../src/auctionMarket.sol";

contract DeployNFTMarket is Script {
    function run() external returns (NFTMarket) {
        vm.startBroadcast();

        NFTMarket NFTMarketContract = new NFTMarket();

        vm.stopBroadcast();

        return NFTMarketContract;
    }
}
