
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {Setup} from "./Setup.sol";

abstract contract Properties is Setup, Asserts {

    function property_observe_always_same() public {
        uint256 valueFromActivePool = activePoolObserver.observe();
        uint256 valueFromTwap = twapWeightedObserver.observe();

        eq(valueFromActivePool, valueFromTwap, "Observe values should be the same");
    }
}
