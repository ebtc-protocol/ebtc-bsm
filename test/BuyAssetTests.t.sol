// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./BSMTestBase.sol";
import {IEbtcBSM} from "../src/Dependencies/IEbtcBSM.sol";
//forge test --match-contract "BuyAssetTests" --verbosity -v
contract BuyAssetTests is BSMTestBase {

    event AssetBought(uint256 ebtcAmountIn, uint256 assetAmountOut, uint256 feeAmount);
    event FeeToBuyUpdated(uint256 oldFee, uint256 newFee);

    function testBuyAssetSuccess(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());
        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;
        uint256 buyerBalance = ebtcAmount * 2;
        _mintAssetToken(testMinter, assetTokenAmount);
        _mintEbtc(testBuyer, buyerBalance);

        _checkAssetTokenBalance(testMinter, assetTokenAmount);

        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, 0);

        _checkAssetTokenBalance(testMinter, 0);
        _checkAssetTokenBalance(testBuyer, 0);
        _checkEbtcBalance(testMinter, ebtcAmount);
        _checkEbtcBalance(testBuyer, buyerBalance);

        vm.recordLogs();
        vm.prank(testBuyer);

        uint256 buyAmount = ebtcAmount / 2;
        assertEq(bsmTester.buyAsset(buyAmount, testBuyer, 0), assetTokenAmount / 2);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("AssetBought(uint256,uint256,uint256)"));
        _checkAssetTokenBalance(testBuyer, assetTokenAmount / 2);
        _checkEbtcBalance(testBuyer, buyerBalance - buyAmount);
    }

    function testBuyAssetFee() public {//TODO clean
        uint256 amount = 5e18;
        uint256 assetAmount = amount * (10 ** mockAssetToken.decimals()) / 1e18;// TODO: standardize

        _mintAssetToken(testMinter, assetAmount);
        _mintEbtc(testAuthorizedUser, amount ** 2);

        uint256 prevAssetBalance = mockAssetToken.balanceOf(testMinter);

        // 1% fee
        vm.prank(techOpsMultisig);
        vm.expectEmit(false, true, false, false);
        emit FeeToBuyUpdated(0, 100);
        bsmTester.setFeeToBuy(100);
        
        vm.recordLogs();
        vm.prank(testMinter);
        bsmTester.sellAsset(assetAmount, testMinter, 0);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("AssetSold(uint256,uint256,uint256)"));

        _checkEbtcBalance(testMinter, amount);
        _checkAssetTokenBalance(testMinter, 0);
        _mintEbtc(testBuyer, 10e18);
        prevAssetBalance = mockEbtcToken.balanceOf(testBuyer);
        uint256 prevTotalAssetsDeposited = escrow.totalAssetsDeposited();
        uint256 buyAmount = 1e18;
        uint256 buyAssetAmount = buyAmount * _assetTokenPrecision() / 1e18;
        uint256 expectedOut = 0.99e18 * _assetTokenPrecision() / 1e18;//TODO

        vm.prank(testBuyer);
        vm.expectEmit(true, false, false, false);
        emit AssetBought(buyAmount, 0, 0);

        assertEq(bsmTester.buyAsset(buyAmount, testBuyer, 0), expectedOut);

        _checkEbtcBalance(testBuyer, 9e18);
        _checkAssetTokenBalance(testBuyer, expectedOut);

        uint256 expectedFee = 0.01e18 * _assetTokenPrecision() / 1e18;//TODO
        assertEq(escrow.feeProfit(), expectedFee);
        assertEq(escrow.totalAssetsDeposited(), prevTotalAssetsDeposited - buyAssetAmount);

        vm.prank(techOpsMultisig);
        escrow.claimProfit();

        assertEq(mockAssetToken.balanceOf(defaultFeeRecipient), expectedFee);
        assertEq(escrow.feeProfit(), 0);
    }

    function testBuyAssetFeeAuthorizedUser() public {
        uint256 amount = 1e18;
        uint256 assetAmount = amount * (10 ** mockAssetToken.decimals()) / 1e18;// TODO: standardize

        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToBuy(100);

        _mintAssetToken(testMinter, amount);
        mockEbtcToken.mint(testAuthorizedUser, amount);
        
        vm.prank(testMinter);
        bsmTester.sellAsset(amount, testMinter, 0);

        vm.expectEmit();
        emit IEbtcBSM.AssetBought(amount, assetAmount, 0);
        
        vm.prank(testAuthorizedUser);
        assertEq(bsmTester.buyAssetNoFee(amount, testAuthorizedUser, 0), assetAmount);
    }

    function testBuyAssetFailAboveTotalAssetsDeposited(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());
        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;// TODO can this just be abstracted?

        _mintEbtc(address(1), ebtcAmount);//TODO check this
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InsufficientAssetTokens.selector, assetTokenAmount, escrow.totalAssetsDeposited()));
        bsmTester.buyAsset(ebtcAmount, address(this), 0);
    }

    function testBuyAssetFailSlippageCheck(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());
        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;
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
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());
        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;
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
}
