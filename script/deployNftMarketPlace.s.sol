// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {NFTMarket} from "../src/nftMarketPlace.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployNFTMarket is Script {
    function run() external returns (NFTMarket) {
        vm.startBroadcast();

        // Convert the address to the DSCEngine contract type
        DSCEngine dscEngine = DSCEngine(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);

        NFTMarket NFTMarketContract = new NFTMarket(dscEngine);

        vm.stopBroadcast();

        return NFTMarketContract;
    }
}
