// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "./BSMTestBase.sol";
import {OraclePriceConstraint} from"../src/OraclePriceConstraint.sol";
import {RateLimitingConstraint} from"../src/RateLimitingConstraint.sol";
import {IConstraint} from "../src/Dependencies/IConstraint.sol";

contract SellAssetTests is BSMTestBase {
     function testSellAssetSuccess(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);

        _mintAssetToken(testMinter, assetTokenAmount);

        _checkAssetTokenBalance(testMinter, assetTokenAmount);
        _checkEbtcBalance(testMinter, 0);

        vm.expectEmit();
        emit IEbtcBSM.AssetSold(assetTokenAmount, ebtcAmount, 0);

        vm.prank(testMinter);
        assertEq(bsmTester.sellAsset(assetTokenAmount, testMinter, 0), ebtcAmount);

        assertEq(bsmTester.totalMinted(), ebtcAmount);
        assertEq(escrow.totalAssetsDeposited(), assetTokenAmount);

        _checkAssetTokenBalance(testMinter, 0);
        _checkEbtcBalance(testMinter, ebtcAmount);
        _checkAssetTokenBalance(address(bsmTester.escrow()), assetTokenAmount);
        _totalMintedEqTotalAssetsDeposited();
    }

    function testSellAssetFeeSuccess(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);
        uint256 sellerBalance = 10 * assetTokenAmount;
        _mintAssetToken(testMinter, sellerBalance);
        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);
        _checkAssetTokenBalance(testMinter, sellerBalance);
        
        uint256 fee = _feeToSell(assetTokenAmount);
        uint256 resultAmount = assetTokenAmount - fee;
        uint256 resultInEbtc = resultAmount * 1e18 / _assetTokenPrecision();

        vm.prank(testMinter);
        assertEq(bsmTester.sellAsset(assetTokenAmount, testMinter, 0), resultInEbtc);
        _checkAssetTokenBalance(testMinter, sellerBalance - assetTokenAmount);
        
        // escrow has user deposit (1e18) + fee(0.01e18) = 1.01e18
        _checkAssetTokenBalance(address(bsmTester.escrow()), assetTokenAmount);

        assertEq(escrow.feeProfit(), fee);
        assertEq(escrow.totalAssetsDeposited(), resultAmount);

        vm.prank(techOpsMultisig);
        escrow.claimProfit();

        _checkAssetTokenBalance(defaultFeeRecipient, fee);
        assertEq(escrow.feeProfit(), 0);
    }

    function testSellAssetFeeAuthorizedUser(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);

        _mintAssetToken(testAuthorizedUser, assetTokenAmount);

        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);

        assertEq(bsmTester.previewSellAssetNoFee(assetTokenAmount), ebtcAmount);

        vm.expectEmit();
        emit IEbtcBSM.AssetSold(assetTokenAmount, ebtcAmount, 0);

        vm.prank(testAuthorizedUser);
        assertEq(bsmTester.sellAssetNoFee(assetTokenAmount, testAuthorizedUser, 0), ebtcAmount);
    }

    function testSellTokenFailureZeroAmount() public {
        vm.prank(testMinter);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.ZeroAmount.selector));
        bsmTester.sellAsset(0, testMinter, 2);
    }

    function testSellTokenFailureInvalidRecipient() public {
        vm.prank(testMinter);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidRecipientAddress.selector));
        bsmTester.sellAsset(1e18, address(0), 2);
    }

    function testSellAssetFailAboveCap(uint256 fraction) public {
        uint256 mintingCapBPS = rateLimitingConstraint.getMintingConfig(address(bsmTester)).relativeCapBPS;
        uint256 maxMint = (mockEbtcToken.totalSupply() *
            mintingCapBPS) / bsmTester.BPS();

        uint256 amountToMint = maxMint + 1;
        uint256 ebtcAmount = amountToMint * 1e18 / _assetTokenPrecision();
        
        vm.prank(testMinter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IConstraint.ConstraintCheckFailed.selector, 
                address(rateLimitingConstraint),
                ebtcAmount,
                address(bsmTester),
                abi.encodeWithSelector(
                    RateLimitingConstraint.AboveMintingCap.selector,
                    ebtcAmount,
                    bsmTester.totalMinted() + ebtcAmount,
                    maxMint
                )
            )
        );
        bsmTester.sellAsset(amountToMint, testMinter, 0);
    }

    function testSellAssetFailBadPrice(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);

        _mintAssetToken(testMinter, assetTokenAmount);

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
                IConstraint.ConstraintCheckFailed.selector,
                address(oraclePriceConstraint),
                ebtcAmount,//must be in ebtc precision
                address(bsmTester),
                abi.encodeWithSelector(
                    OraclePriceConstraint.BelowMinPrice.selector, 
                    0.89e18, // assetPrice
                    0.9e18   // acceptable min price
                )
            )
        );
        
        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, 0);
    }

    function testSellAssetOracleTooOld() public {

        uint256 nowTime = block.timestamp;

        vm.warp(block.timestamp + oraclePriceConstraint.oracleFreshnessSeconds() + 1);

        vm.expectRevert(abi.encodeWithSelector(OraclePriceConstraint.StaleOraclePrice.selector, nowTime));
        vm.prank(testMinter);
        bsmTester.sellAsset(1e18, testMinter, 0);
    }

    function testSellAssetFailPaused(uint256 numTokens, uint256 fraction) public {
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

        testSellAssetSuccess(numTokens, fraction);
    }

    function testSellAssetFailSlippageCheck(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);

        _mintAssetToken(testMinter, assetTokenAmount);
        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);

        // TEST: fail if actual < expected
        uint256 realAmount = bsmTester.previewSellAsset(assetTokenAmount);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.BelowExpectedMinOutAmount.selector, realAmount * 2, realAmount));
        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, realAmount * 2);

        // TEST: pass if actual >= expected
        vm.prank(testMinter);
        assertEq(bsmTester.sellAsset(assetTokenAmount, testMinter, realAmount), realAmount);
    }
}
