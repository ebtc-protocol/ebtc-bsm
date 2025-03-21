// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {BSMBase} from "./BSMBase.sol";
import "../src/EbtcBSM.sol";

contract BSMTestBase is BSMBase, Test {
    function testBsmCannotBeReinitialize() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        bsmTester.initialize(address(escrow));
    }

    function setUp() public virtual {
        BSMBase.baseSetup(18);
    }
}
