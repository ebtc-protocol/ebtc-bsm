// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract PreviewTests is BaseTargetFunctions, Properties {
    function equivalence_bsm_previewBuyAsset(uint256 _ebtcAmountIn) public stateless {
        require(escrow.totalBalance() > 1e18, "Min bal"); // Should not matter

        uint256 amtOut = bsmTester.previewBuyAsset(_ebtcAmountIn);

        vm.prank(_getActor());
        uint256 realOut = bsmTester.buyAsset(_ebtcAmountIn, _getActor(), 0);

        eq(realOut, amtOut, "equivalence_bsm_previewBuyAsset");
    }

    function equivalence_bsm_previewSellAsset(uint256 _assetAmountIn) public stateless {
        uint256 amtOut = bsmTester.previewSellAsset(_assetAmountIn);

        vm.prank(_getActor());
        uint256 realOut = bsmTester.sellAsset(_assetAmountIn, _getActor(), 0);

        eq(realOut, amtOut, "equivalence_bsm_previewSellAsset");
    }

    // Feeless comparison
    function equivalence_bsm_previewBuyAssetNoFee(uint256 _ebtcAmountIn) public stateless {
        require(escrow.totalBalance() > 1e18, "Min bal"); // Should not matter

        uint256 amtOut = bsmTester.previewBuyAssetNoFee(_ebtcAmountIn);

        vm.prank(_getActor());
        uint256 realOut = bsmTester.buyAssetNoFee(_ebtcAmountIn, _getActor(), 0);

        eq(realOut, amtOut, "equivalence_bsm_previewBuyAsset");
    }

    function equivalence_bsm_previewSellAssetNoFee(uint256 _assetAmountIn) public stateless {
        uint256 amtOut = bsmTester.previewSellAssetNoFee(_assetAmountIn);

        vm.prank(_getActor());
        uint256 realOut = bsmTester.sellAssetNoFee(_assetAmountIn, _getActor(), 0);

        eq(realOut, amtOut, "equivalence_bsm_previewSellAsset");
    }
}
