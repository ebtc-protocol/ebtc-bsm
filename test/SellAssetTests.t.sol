// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./BSMTestBase.sol";
import {OraclePriceConstraint} from"../src/OraclePriceConstraint.sol";
import {RateLimitingConstraint} from"../src/RateLimitingConstraint.sol";
import {IMintingConstraint} from "../src/Dependencies/IMintingConstraint.sol";

contract SellAssetTests is BSMTestBase {
    function testSellAssetSuccess(uint256 numTokens) public {
        numTokens = bound(numTokens, 1, 1000000000);

        uint256 ebtcAmount = _getEbtcAmount(numTokens);
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens);

        _mintAssetToken(testMinter, numTokens);

        _checkAssetTokenBalance(testMinter, numTokens);
        _checkEbtcBalance(testMinter, 0);

        uint256 fee = assetTokenAmount * bsmTester.feeToBuyBPS() / (bsmTester.feeToBuyBPS() + bsmTester.BPS());

        vm.expectEmit();
        emit IEbtcBSM.AssetSold(assetTokenAmount, ebtcAmount, fee);

        vm.prank(testMinter);
        assertEq(bsmTester.sellAsset(assetTokenAmount, testMinter, 0), ebtcAmount);

        assertEq(bsmTester.totalMinted(), ebtcAmount);
        assertEq(escrow.totalAssetsDeposited(), assetTokenAmount);

        _checkAssetTokenBalance(testMinter, 0);
        _checkEbtcBalance(testMinter, numTokens);
        _checkAssetTokenBalance(address(bsmTester.escrow()), numTokens);
        _totalMintedEqTotalAssetsDeposited();
    }

    function testSellAssetFeeSuccess() public {
        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);

        assertEq(mockAssetToken.balanceOf(testMinter), 10e18);

        vm.expectEmit();
        emit IEbtcBSM.AssetSold(1.01e18, 1e18, 0.01e18);

        vm.prank(testMinter);
        assertEq(bsmTester.sellAsset(1.01e18, testMinter, 0), 1e18);

        assertEq(mockAssetToken.balanceOf(testMinter), 8.99e18);

        // escrow has user deposit (1e18) + fee(0.01e18) = 1.01e18
        assertEq(
            mockAssetToken.balanceOf(address(bsmTester.escrow())),
            1.01e18
        );
        assertEq(escrow.feeProfit(), 0.01e18);
        assertEq(escrow.totalAssetsDeposited(), 1e18);

        vm.prank(techOpsMultisig);
        escrow.claimProfit();

        assertEq(mockAssetToken.balanceOf(defaultFeeRecipient), 0.01e18);
        assertEq(escrow.feeProfit(), 0);
    }

    function testSellAssetFeeAuthorizedUser() public {
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);

        vm.expectEmit();
        emit IEbtcBSM.AssetSold(1.01e18, 1.01e18, 0);

        vm.prank(testAuthorizedUser);
        assertEq(bsmTester.sellAssetNoFee(1.01e18, testAuthorizedUser, 0), 1.01e18);
    }

    function testSellTokenFailureZeroAmount() public {

    }

    function testSellTokenFailureInvalidRecipient() public {

    }

    function testSellAssetFailAboveCap() public {
        uint256 mintingCapBPS = rateLimitingConstraint.getMintingConfig(address(bsmTester)).relativeCapBPS;

        uint256 amountToMint = (mockEbtcToken.totalSupply() *
            (mintingCapBPS + 1)) / bsmTester.BPS();
        uint256 maxMint = (mockEbtcToken.totalSupply() *
            mintingCapBPS) / bsmTester.BPS();

        vm.prank(testMinter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IMintingConstraint.MintingConstraintCheckFailed.selector, 
                address(rateLimitingConstraint),
                amountToMint,
                address(bsmTester),
                abi.encodeWithSelector(
                    RateLimitingConstraint.AboveMintingCap.selector,
                    amountToMint,
                    bsmTester.totalMinted() + amountToMint,
                    maxMint
                )
            )
        );
        bsmTester.sellAsset(amountToMint, testMinter, 0);
    }

    function testSellAssetFailBadPrice() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        oraclePriceConstraint.setMinPrice(9000);

        // set min price to 90% (0.9 min price)
        vm.prank(techOpsMultisig);
        oraclePriceConstraint.setMinPrice(9000);

        // Drop price to 0.89
        mockAssetOracle.setPrice(0.89e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                IMintingConstraint.MintingConstraintCheckFailed.selector,
                address(oraclePriceConstraint),
                1e18,
                address(bsmTester),
                abi.encodeWithSelector(
                    OraclePriceConstraint.BelowMinPrice.selector, 
                    0.89e18, // assetPrice
                    0.9e18   // acceptable min price
                )
            )
        );
        vm.prank(testMinter);
        bsmTester.sellAsset(1e18, testMinter, 0);
    }

    function testSellAssetOracleTooOld() public {

        uint256 nowTime = block.timestamp;

        vm.warp(block.timestamp + oraclePriceConstraint.oracleFreshnessSeconds() + 1);

        vm.expectRevert(abi.encodeWithSelector(OraclePriceConstraint.StaleOraclePrice.selector, nowTime));
        vm.prank(testMinter);
        bsmTester.sellAsset(1e18, testMinter, 0);
    }

    function testSellAssetFailPaused(uint256 numTokens) public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.pause();

        vm.prank(techOpsMultisig);
        bsmTester.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(testMinter);
        bsmTester.sellAsset(1e18, testMinter, 0);

        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.unpause();

        vm.prank(techOpsMultisig);
        bsmTester.unpause();

        testSellAssetSuccess(numTokens);
    }

    function testSellAssetFailSlippageCheck() public {
        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);

        // TEST: fail if actual < expected
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.BelowExpectedMinOutAmount.selector, 1.01e18, 1e18));
        vm.prank(testMinter);
        bsmTester.sellAsset(1.01e18, testMinter, 1.01e18);

        // TEST: pass if actual >= expected
        vm.prank(testMinter);
        assertEq(bsmTester.sellAsset(1.01e18, testMinter, 1e18), 1e18);
    }
}
