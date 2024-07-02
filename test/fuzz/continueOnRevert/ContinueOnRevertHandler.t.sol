// Commented out for now until revert on fail == false per function customization is implemented

// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Test } from "forge-std/Test.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";

import { MockV3Aggregator } from "../../mocks/MockV3Aggregator.sol";
import { DSCEngine, AggregatorV3Interface } from "../../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../../src/DecentralizedStableCoin.sol";
// import {Randomish, EnumerableSet} from "../Randomish.sol"; // Randomish is not found in the codebase, EnumerableSet
// is imported from openzeppelin
import { console } from "forge-std/console.sol";

contract ContinueOnRevertHandler is Test {
    // using EnumerableSet for EnumerableSet.AddressSet;
    // using Randomish for EnumerableSet.AddressSet;

    // Deployed contracts to interact with
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    enum CollateralToken {
        TSH,
        ALP
    }


    // Ghost Variables
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
    }

    // FUNCTOINS TO INTERACT WITH

    ///////////////
    // DSCEngine //
    ///////////////
    function mintAndDepositCollateral(uint8 token, uint256 amountCollateral) public {

        token = uint8(bound(token, 0, uint8(DSCEngine.CollateralToken.ALP)));

        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);

        DSCEngine.CollateralToken tokenType = DSCEngine.CollateralToken(token);
        
        dscEngine.depositCollateral(tokenType, amountCollateral);
    }


    function redeemCollateral(uint8 token, uint256 amountCollateral) public {
        // Bound the token to the valid enum range
        token = uint8(bound(token, 0, uint8(DSCEngine.CollateralToken.ALP)));

        // Convert the token to the enum type
        DSCEngine.CollateralToken tokenType = DSCEngine.CollateralToken(token);

        // Ensure the amountCollateral is within the expected bounds
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);

        // Try to redeem collateral
        dscEngine.redeemCollateral(tokenType, amountCollateral);
    }

    function burnDsc(uint256 amountDsc) public {
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        dsc.burn(amountDsc);
    }

    function mintDsc(uint256 amountDsc) public {
        amountDsc = bound(amountDsc, 0, MAX_DEPOSIT_SIZE);
        dsc.mint(msg.sender, amountDsc);
    }

    /////////////////////////////
    // DecentralizedStableCoin //
    /////////////////////////////
    function transferDsc(uint256 amountDsc, address to) public {
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        vm.prank(msg.sender);
        dsc.transfer(to, amountDsc);
    }


    /// Helper Functions
    function callSummary() external view {
        console.log("Total supply of DSC", dsc.totalSupply());
    }
}
