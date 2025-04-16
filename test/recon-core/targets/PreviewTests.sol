// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract PreviewTests is BaseTargetFunctions, Properties {
    function equivalence_bsm_previewBuyAsset(uint256 _ebtcAmountIn) public stateless {
        uint256 amtOut;
        bool previewRevert;

        try bsmTester.previewBuyAsset(_ebtcAmountIn) returns (uint256 amt) {
            amtOut = amt;
        } catch {
            previewRevert = true;
        }
        
        uint256 realOut;
        bool buyRevert;

        vm.prank(_getActor());
        try bsmTester.buyAsset(_ebtcAmountIn, _getActor(), 0) returns (uint256 amt) {
            realOut = amt;
        } catch {
            buyRevert = true;
        }

        t(buyRevert == previewRevert, "reverts equivalence_bsm_previewBuyAsset");
        eq(realOut, amtOut, "amt equivalence_bsm_previewBuyAsset");
    }

    function equivalence_bsm_previewSellAsset(uint256 _assetAmountIn) public stateless {
        uint256 amtOut;
        bool previewRevert;

        try bsmTester.previewSellAsset(_assetAmountIn) returns (uint256 amt) {
            amtOut = amt;
        } catch {
            previewRevert = true;
        }

        
        uint256 realOut;
        bool buyRevert;

        vm.prank(_getActor());
        try bsmTester.sellAsset(_assetAmountIn, _getActor(), 0) returns (uint256 amt) {
            realOut = amt;
        } catch {
            buyRevert = true;
        }

        t(buyRevert == previewRevert, "reverts equivalence_bsm_previewSellAsset");
        eq(realOut, amtOut, "amt equivalence_bsm_previewSellAsset");
    }

    // Feeless comparison
    function equivalence_bsm_previewBuyAssetNoFee(uint256 _ebtcAmountIn) public stateless {
        uint256 amtOut;
        bool previewRevert;

        try bsmTester.previewBuyAssetNoFee(_ebtcAmountIn) returns (uint256 amt) {
            amtOut = amt;
        } catch {
            previewRevert = true;
        }

        
        uint256 realOut;
        bool buyRevert;

        vm.prank(_getActor());
        try bsmTester.buyAssetNoFee(_ebtcAmountIn, _getActor(), 0) returns (uint256 amt) {
            realOut = amt;
        } catch {
            buyRevert = true;
        }

        t(buyRevert == previewRevert, "reverts equivalence_bsm_previewBuyAssetNoFee");
        eq(realOut, amtOut, "amt equivalence_bsm_previewBuyAssetNoFee");
    }

    function equivalence_bsm_previewSellAssetNoFee(uint256 _assetAmountIn) public stateless {
        uint256 amtOut;
        bool previewRevert;

        try bsmTester.previewSellAssetNoFee(_assetAmountIn) returns (uint256 amt) {
            amtOut = amt;
        } catch {
            previewRevert = true;
        }

        
        uint256 realOut;
        bool buyRevert;
        vm.prank(_getActor());
        try bsmTester.sellAssetNoFee(_assetAmountIn, _getActor(), 0) returns (uint256 amt) {
            realOut = amt;
        } catch {
            buyRevert = true;
        }

        t(buyRevert == previewRevert, "reverts equivalence_bsm_previewSellAssetNoFee");
        eq(realOut, amtOut, "amt equivalence_bsm_previewSellAssetNoFee");
    }
}
