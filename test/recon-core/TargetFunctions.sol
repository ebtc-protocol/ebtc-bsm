// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import {AdminTargets} from "./targets/AdminTargets.sol";
import {InlinedTests} from "./targets/InlinedTests.sol";
import {ManagersTargets} from "./targets/ManagersTargets.sol";
import {PreviewTests} from "./targets/PreviewTests.sol";

import {OpType} from "./BeforeAfter.sol";

abstract contract TargetFunctions is AdminTargets, InlinedTests, ManagersTargets, PreviewTests {
    /// INTERNAL ///
    // NOTE: Could use a Lib or make them public, but not a huge deal
    function _toAssetPrecision(uint256 _amount) private view returns (uint256)  {
        return _amount * bsmTester.ASSET_TOKEN_PRECISION() / 1e18;
    }

    function _toEbtcPrecision(uint256 _amount) private view returns (uint256) {
        return _amount * 1e18 / bsmTester.ASSET_TOKEN_PRECISION();
    }

    function bsmTester_buyAsset(uint256 _ebtcAmountIn)
        public
        updateGhostsWithType(OpType.BUY_ASSET_WITH_EBTC)
        asActor
    {
        uint256 assetOut = bsmTester.buyAsset(_ebtcAmountIn, _getActor(), 0);

        // Inlined test for Rounding
        // _ebtcAmountIn > _toEbtcPrecision(assetOut) if there's any fee
        if(bsmTester.feeToBuyBPS() > 0) {
            lt(_toEbtcPrecision(assetOut), _ebtcAmountIn,  "Asset Out is less than eBTC In when you have fees");
        }
    }

    function bsmTester_sellAsset(uint256 _assetAmountIn) public updateGhosts asActor {
        uint256 eBTCOut = bsmTester.sellAsset(_assetAmountIn, _getActor(), 0);

        // Inlined test for rounding
        if(bsmTester.feeToSellBPS() > 0) {
            lt(_toAssetPrecision(eBTCOut), _assetAmountIn,  "eBTC Is less than asset amt in due to fees");
        }
    }

    // Donations directly to the underlying vault
    function externalVault_mint(uint256 _amount) public updateGhosts asActor {
        externalVault.deposit(_amount, _getActor());
    }

    function externalVault_withdraw(uint256 _amount) public updateGhosts asActor {
        externalVault.withdraw(_amount, _getActor(), _getActor());
    }
}
