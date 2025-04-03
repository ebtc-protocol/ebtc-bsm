// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "./BSMTestBase.sol";
import {IEbtcBSM} from "../src/Dependencies/IEbtcBSM.sol";

contract BuyAssetTests is BSMTestBase {

    event AssetBought(uint256 ebtcAmountIn, uint256 assetAmountOut, uint256 feeAmount);
    event FeeToBuyUpdated(uint256 oldFee, uint256 newFee);

    function testBuyAssetSuccess(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);
        uint256 buyerBalance = ebtcAmount * 2;
        _mintAssetToken(testMinter, assetTokenAmount);
        _mintEbtc(testBuyer, buyerBalance);

        _checkAssetTokenBalance(testMinter, assetTokenAmount);

        uint256 buyAmount = ebtcAmount / 2;

        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, 0);

        _checkAssetTokenBalance(testMinter, 0);
        _checkAssetTokenBalance(testBuyer, 0);
        _checkEbtcBalance(testMinter, ebtcAmount);
        _checkEbtcBalance(testBuyer, buyerBalance);

        // TEST: make sure preview is correct
        assertEq(bsmTester.previewBuyAsset(buyAmount), assetTokenAmount / 2);

        vm.recordLogs();
        vm.prank(testBuyer);

        assertEq(bsmTester.buyAsset(buyAmount, testBuyer, 0), assetTokenAmount / 2);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("AssetBought(uint256,uint256,uint256)"));
        _checkAssetTokenBalance(testBuyer, assetTokenAmount / 2);
        _checkEbtcBalance(testBuyer, buyerBalance - buyAmount);
    }

    function testBuyAssetFee(
        uint256 numSellTokens, 
        uint256 sellFraction,
        uint256 numBuyTokens,
        uint256 buyFraction
    ) public {
        (uint256 ebtcSellAmount, uint256 assetTokenSellAmount) = _getTestData(numSellTokens, sellFraction);
        (uint256 ebtcBuyAmount, uint256 assetTokenBuyAmount) = _getTestData(numBuyTokens, buyFraction);

        ebtcBuyAmount = bound(ebtcBuyAmount, 1, ebtcSellAmount);
        assetTokenBuyAmount = bound(assetTokenBuyAmount, 1, assetTokenSellAmount);

        _mintAssetToken(testMinter, assetTokenSellAmount);
        _mintEbtc(testAuthorizedUser, ebtcSellAmount);

        // 1% fee
        vm.prank(techOpsMultisig);
        vm.expectEmit(address(bsmTester));
        emit FeeToBuyUpdated(0, 100);
        bsmTester.setFeeToBuy(100);

        vm.recordLogs();
        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenSellAmount, testMinter, 0);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("AssetSold(uint256,uint256,uint256)"));

        _checkEbtcBalance(testMinter, ebtcSellAmount);
        _checkAssetTokenBalance(testMinter, 0);
        _mintEbtc(testBuyer, ebtcBuyAmount);

        uint256 prevTotalAssetsDeposited = escrow.totalAssetsDeposited();
        uint256 fee = _feeToBuy(ebtcBuyAmount);
        uint256 expectedOut = assetTokenBuyAmount - fee;

        // TEST: make sure preview is correct
        assertEq(bsmTester.previewBuyAsset(ebtcBuyAmount), expectedOut);
        bsmTester.previewBuyAsset(ebtcBuyAmount);
        vm.prank(testBuyer);
        vm.expectEmit(address(bsmTester));
        emit AssetBought(ebtcBuyAmount, expectedOut, fee);

        assertEq(bsmTester.buyAsset(ebtcBuyAmount, testBuyer, 0), expectedOut);

        _checkEbtcBalance(testBuyer, 0);
        _checkAssetTokenBalance(testBuyer, expectedOut);

        assertEq(escrow.feeProfit(), fee);
        assertEq(escrow.totalAssetsDeposited(), prevTotalAssetsDeposited - assetTokenBuyAmount);

        vm.prank(techOpsMultisig);
        escrow.claimProfit();

        _checkAssetTokenBalance(defaultFeeRecipient, fee);
        assertEq(escrow.feeProfit(), 0);
    }

    function testBuyAssetFeeAuthorizedUser(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);

        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToBuy(100);

        _mintAssetToken(testMinter, assetTokenAmount);
        _mintEbtc(testAuthorizedUser, ebtcAmount);
        
        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, 0);

        // TEST: make sure preview is correct
        assertEq(bsmTester.previewBuyAssetNoFee(ebtcAmount), assetTokenAmount);

        vm.expectEmit();
        emit IEbtcBSM.AssetBought(ebtcAmount, assetTokenAmount, 0);
        
        vm.prank(testAuthorizedUser);
        assertEq(bsmTester.buyAssetNoFee(ebtcAmount, testAuthorizedUser, 0), assetTokenAmount);
    }

    function testBuyAssetFailAboveTotalAssetsDeposited(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);

        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InsufficientAssetTokens.selector, assetTokenAmount, escrow.totalAssetsDeposited()));
        bsmTester.buyAsset(ebtcAmount, address(this), 0);
    }

    function testBuyAssetFailSlippageCheck(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);
        uint256 buyerBalance = ebtcAmount;
        uint256 sellerBalance = 5 * assetTokenAmount;
        _mintAssetToken(testMinter, sellerBalance);
        _mintEbtc(testBuyer, buyerBalance);
        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToBuy(100);
        
        _mintAssetToken(testMinter, sellerBalance);
        vm.prank(testMinter);
        bsmTester.sellAsset(sellerBalance, testMinter, 0);
        
        // TEST: fail if actual < expected
        uint256 realAmount = bsmTester.previewBuyAsset(buyerBalance);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.BelowExpectedMinOutAmount.selector, realAmount * 2, realAmount));
        vm.prank(testBuyer);
        bsmTester.buyAsset(buyerBalance, testBuyer, realAmount * 2);
        
        // TEST: pass if actual >= expected
        vm.prank(testBuyer);
        assertEq(bsmTester.buyAsset(buyerBalance, testBuyer, realAmount), realAmount);
    }

    function testPreviewBuyAssetAndLiquidity(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);
        uint256 withdrawAmountEbtc = 3 * ebtcAmount;
        uint256 withdrawAmountAsset = 3 * assetTokenAmount;

        // With liquidity
        _mintAssetToken(testMinter, 5 * assetTokenAmount);
        vm.prank(testMinter);
        bsmTester.sellAsset(5 * assetTokenAmount, testMinter, 0);
        
        uint256 liquidBalance = mockAssetToken.balanceOf(address(escrow));
        // Ensure liquidity surplus
        assertGt(liquidBalance, withdrawAmountAsset);
        // Preview withdraw does not redeem
        uint256 beforeShares = externalVault.balanceOf(address(escrow));
        uint256 amtOut = bsmTester.previewBuyAsset(withdrawAmountEbtc);
        _mintEbtc(testBuyer, withdrawAmountEbtc);
        vm.prank(testBuyer);
        uint256 realOut = bsmTester.buyAsset(withdrawAmountEbtc, testBuyer, 0);
        uint256 afterShares = externalVault.balanceOf(address(escrow));

        assertEq(amtOut, realOut);
        assertEq(afterShares, beforeShares);// No redeem happened
        
        // With no liquidity
        withdrawAmountAsset = 2 * assetTokenAmount;
        withdrawAmountEbtc = 2 * ebtcAmount;
        uint256 shares = externalVault.previewDeposit(withdrawAmountAsset);
        vm.prank(techOpsMultisig);
        escrow.depositToExternalVault(withdrawAmountAsset, shares);
        liquidBalance = mockAssetToken.balanceOf(address(escrow));
        // Ensure liquidity deficit
        assertGt(withdrawAmountAsset, liquidBalance);
        
        // Preview withdraw should take into account redeem amount
        beforeShares = externalVault.balanceOf(address(escrow));
        amtOut = bsmTester.previewBuyAsset(withdrawAmountEbtc);
        _mintEbtc(testBuyer, withdrawAmountEbtc);
        vm.prank(testBuyer);
        realOut = bsmTester.buyAsset(withdrawAmountEbtc, testBuyer, 0);

        afterShares = externalVault.balanceOf(address(escrow));

        assertEq(amtOut, realOut);
        assertLt(afterShares, beforeShares);// Redeem happened
    }

    function testBuyAssetReverts() public {
        vm.prank(testMinter);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.ZeroAmount.selector));
        bsmTester.buyAsset(0, testMinter, 2);

        vm.prank(testMinter);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidRecipientAddress.selector));
        bsmTester.buyAsset(1e18, address(0), 2);
    }
}
