
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";

import {ActivePoolObserver} from "src/ActivePoolObserver.sol";

import {TwapWeightedObserver} from "./helpers/TwapWeightedObserver.sol";

abstract contract Setup is BaseSetup {
    ActivePoolObserver activePoolObserver;
    TwapWeightedObserver twapWeightedObserver;
    
    function setup() internal virtual override {
      twapWeightedObserver = new TwapWeightedObserver(100);
      activePoolObserver = new ActivePoolObserver(twapWeightedObserver);
    }
}
