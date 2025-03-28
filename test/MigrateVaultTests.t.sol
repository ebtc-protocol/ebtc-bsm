// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./BSMTestBase.sol";
import "../src/BaseEscrow.sol";
import "../src/ERC4626Escrow.sol";
import "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";

contract MigrateAssetVaultTest is BSMTestBase {
    ERC4626Escrow internal newEscrow;

    function setUp() public virtual override {
        super.setUp();

        newEscrow = new ERC4626Escrow(
            address(externalVault),
            address(bsmTester.ASSET_TOKEN()),
            address(bsmTester),
            address(bsmTester.authority()),
            address(escrow.FEE_RECIPIENT())
        );
        _mintAssetToken(techOpsMultisig, 10e18);
        vm.prank(techOpsMultisig);
        mockAssetToken.approve(address(bsmTester), type(uint256).max);
    }

    function testBasicScenario() public {
        vm.expectEmit();
        emit IEbtcBSM.EscrowUpdated(address(bsmTester.escrow()), address(newEscrow));
        
        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(newEscrow));

        assertEq(address(bsmTester.escrow()), address(newEscrow));  
    }

    function testMigrationAssets(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());

        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;

        _mintAssetToken(testMinter, assetTokenAmount);

        _checkAssetTokenBalance(testMinter, assetTokenAmount);
        _checkEbtcBalance(testMinter, 0);

        uint256 fee = assetTokenAmount * bsmTester.feeToBuyBPS() / (bsmTester.feeToBuyBPS() + bsmTester.BPS());

        vm.expectEmit();
        emit IEbtcBSM.AssetSold(assetTokenAmount, ebtcAmount, fee);

        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, 0);
        
        _mintEbtc(testBuyer, ebtcAmount);
        
        vm.prank(testBuyer);
        assertEq(bsmTester.buyAsset(ebtcAmount / 2, testBuyer, 0), assetTokenAmount / 2);//ensure there is still balance before migration

        uint256 resultingAssets = (assetTokenAmount + 2 - 1)/ 2; // round up
        uint256 prevTotalDeposit = escrow.totalAssetsDeposited();
        uint256 prevBalance = escrow.totalBalance();
        assertEq(prevTotalDeposit, resultingAssets);
        assertGt(prevBalance, 0);

        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(newEscrow));
        // Old Vault
        uint256 crtTotalDeposit = escrow.totalAssetsDeposited();
        uint256 crtBalance = escrow.totalBalance();
        assertEq(crtTotalDeposit, 0);
        assertEq(crtBalance, 0);
        // New Vault
        uint256 totalDeposit = newEscrow.totalAssetsDeposited();
        uint256 balance = newEscrow.totalBalance();
        assertEq(totalDeposit, prevTotalDeposit);
        assertEq(balance, resultingAssets);
    }

    function testMigrationWithProfit(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());

        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;

        _mintAssetToken(testMinter, assetTokenAmount);

        _checkAssetTokenBalance(testMinter, assetTokenAmount);
        _checkEbtcBalance(testMinter, 0);

        // make profit
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);
        uint256 fee = assetTokenAmount * bsmTester.feeToSellBPS() / (bsmTester.feeToSellBPS() + bsmTester.BPS());console.log("Vi",ebtcAmount - fee, ebtcAmount, fee);
        uint256 resultAmount = assetTokenAmount - fee;
        uint256 resultInEbtc = resultAmount * 1e18 / _assetTokenPrecision();
        
        vm.prank(testMinter);
        assertEq(bsmTester.sellAsset(assetTokenAmount, testMinter, 0), resultInEbtc);
        
        uint256 profit = escrow.feeProfit();
        uint256 prevFeeRecipientBalance = escrow.ASSET_TOKEN().balanceOf(escrow.FEE_RECIPIENT());
        // migrate escrow
        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(newEscrow));
        uint256 feeRecipientBalance = escrow.ASSET_TOKEN().balanceOf(escrow.FEE_RECIPIENT());
        
        assertEq(escrow.totalBalance(), escrow.totalAssetsDeposited());
        assertEq(escrow.feeProfit(), 0);
        assertEq(feeRecipientBalance, profit);
        assertGt(feeRecipientBalance, prevFeeRecipientBalance);
    }

    function testRevertScenarios() public {
        vm.expectRevert(abi.encodeWithSelector(BaseEscrow.CallerNotBSM.selector));
        escrow.onMigrateTarget(1e18);
        vm.expectRevert(abi.encodeWithSelector(BaseEscrow.CallerNotBSM.selector));
        escrow.onMigrateSource(address(newEscrow));
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        bsmTester.updateEscrow(address(newEscrow));

        vm.prank(techOpsMultisig);
        vm.expectRevert();
        bsmTester.updateEscrow(address(0));
    }
    
    function testMigrationWithExtLending(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());

        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;

        _mintAssetToken(techOpsMultisig, assetTokenAmount);

        uint256 assetAmount = assetTokenAmount;
        // operations including selling, and buying assets, as well as external lending
        vm.prank(techOpsMultisig);
        bsmTester.sellAsset(assetTokenAmount, address(this), 0);

        uint256 shares = externalVault.previewDeposit(assetAmount);
        vm.prank(techOpsMultisig);
        escrow.depositToExternalVault(assetAmount, shares);

        _mintEbtc(testBuyer, ebtcAmount / 2);
        vm.prank(testBuyer);
        bsmTester.buyAsset(ebtcAmount / 2, testBuyer, 0);

        assertGt(escrow.totalAssetsDeposited(), 0);
        assertGt(externalVault.balanceOf(address(escrow)), 0);

        uint256 redeemAmount = (shares + 2 - 1)/ 2; // round up
        
        vm.prank(techOpsMultisig);
        escrow.redeemFromExternalVault(redeemAmount , assetAmount / 2);
        // Migrate escrow
        uint256 totalAssetsDeposited = escrow.totalAssetsDeposited();
        uint256 escrowBalance = externalVault.balanceOf(address(escrow));
        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(newEscrow));

        assertEq(escrow.totalAssetsDeposited(), 0);
        assertEq(newEscrow.totalAssetsDeposited(), totalAssetsDeposited);
        assertEq(externalVault.balanceOf(address(escrow)), 0);
        assertEq(externalVault.balanceOf(address(newEscrow)), escrowBalance);
    }

    function testProfitAndExtLending(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());
        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;

        vm.prank(techOpsMultisig);
    	bsmTester.setFeeToSell(100);

        // operations including selling, and buying assets, as well as external lending
        _mintAssetToken(techOpsMultisig, assetTokenAmount);
        vm.prank(techOpsMultisig);
        bsmTester.sellAsset(assetTokenAmount, address(this), 0);
        uint256 profit = escrow.feeProfit();

        assertGt(profit, 0);

        uint256 shares = externalVault.previewDeposit(assetTokenAmount);
        vm.prank(techOpsMultisig);
        escrow.depositToExternalVault(assetTokenAmount, shares);

        _mintEbtc(testBuyer, ebtcAmount);
        vm.prank(testBuyer);
        bsmTester.buyAsset(ebtcAmount / 2, testBuyer, 0);

        assertGt(escrow.totalAssetsDeposited(), 0);
        assertGt(externalVault.balanceOf(address(escrow)), 0);
        
        uint256 redeemAmount = (shares + 2 - 1)/ 2; // round up
        vm.prank(techOpsMultisig);
        escrow.redeemFromExternalVault(redeemAmount , assetTokenAmount / 2);
        // Migrate escrow
        uint256 totalAssetsDeposited = escrow.totalAssetsDeposited();
        uint256 escrowBalance = externalVault.balanceOf(address(escrow));
        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(newEscrow));

        assertEq(escrow.totalAssetsDeposited(), 0);
        assertEq(newEscrow.totalAssetsDeposited(), totalAssetsDeposited);
        assertEq(externalVault.balanceOf(address(escrow)), 0);
        assertEq(externalVault.balanceOf(address(newEscrow)), escrowBalance);
    }

    function testMigrationWithExternalVaultLoss(uint256 numTokens, uint256 fraction) public {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());

        uint256 ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        uint256 assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;

        _mintAssetToken(techOpsMultisig, assetTokenAmount);

        uint256 assetAmount = assetTokenAmount;
        // operations including selling, and buying assets, as well as external lending
        vm.prank(techOpsMultisig);
        bsmTester.sellAsset(assetTokenAmount, address(this), 0);

        uint256 shares = externalVault.previewDeposit(assetAmount);
        vm.prank(techOpsMultisig);
        escrow.depositToExternalVault(assetAmount, shares);

        // 50% external vault loss
        vm.prank(address(externalVault));
        mockAssetToken.transfer(vm.addr(0xdead), assetAmount / 2);

        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(newEscrow));
        uint256 depositAmount = (assetAmount + 2 - 1)/ 2; // round up
        _checkAssetTokenBalance(address(newEscrow), depositAmount);
        assertEq(newEscrow.totalAssetsDeposited(), assetAmount);
    }
}