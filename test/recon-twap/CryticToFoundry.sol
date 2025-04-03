
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }

    function test_manual_qa() public {
        twapWeightedObserver_setValueAndUpdate(44265688792424285613);
        vm.warp(block.timestamp + 24 days);
        property_observe_always_same();
    }
}
