// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// // Invariants:
// // protocol must never be insolvent / undercollateralized
// // users cant create stablecoins with a bad health factor
// // a user should only be able to be liquidated if they have a bad health factor

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { DSCEngine } from "../../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../../src/DecentralizedStableCoin.sol";
import { HelperConfig } from "../../../script/HelperConfig.s.sol";
import { DeployDSC } from "../../../script/DeployDSC.s.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { ContinueOnRevertHandler } from "./ContinueOnRevertHandler.t.sol";
import { console } from "forge-std/console.sol";

contract ContinueOnRevertInvariants is StdInvariant, Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public constant USER = address(1);




    ContinueOnRevertHandler public handler;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce) = deployer.run();
        handler = new ContinueOnRevertHandler(dsce, dsc);
        targetContract(address(handler));
        // targetContract(address(ethUsdPriceFeed));// Why can't we just do this?
    }

    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
