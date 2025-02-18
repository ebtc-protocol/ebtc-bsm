
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Properties {

    function twapWeightedObserver_setValueAndUpdate(uint128 _value) public {
        vm.prank(address(twapWeightedObserver));
        twapWeightedObserver.setValueAndUpdate(_value);
    }

    function twapWeightedObserver_update() public {
        twapWeightedObserver.update();
    }
}
