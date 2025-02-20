// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract PreviewTests is BaseTargetFunctions, Properties {
    function bsm_previewBuyAsset(uint256 _ebtcAmountIn) public stateless {
        uint256 amtOut = bsmTester.previewBuyAsset(_ebtcAmountIn);

        vm.prank(_getActor());
        uint256 realOut = bsmTester.buyAsset(_ebtcAmountIn, _getActor());

        eq(realOut, amtOut, "bsm_previewBuyAsset");
    }

    function bsm_previewSellAsset(uint256 _assetAmountIn) public stateless {
        uint256 amtOut = bsmTester.previewSellAsset(_assetAmountIn);

        vm.prank(_getActor());
        uint256 realOut = bsmTester.sellAsset(_assetAmountIn, _getActor());

        eq(realOut, amtOut, "bsm_previewSellAsset");
    }
}
