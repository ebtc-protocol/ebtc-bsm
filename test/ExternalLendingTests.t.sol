// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC4626Escrow} from "../src/ERC4626Escrow.sol";
import "./BSMTestBase.sol";

contract ExternalLendingTests is BSMTestBase {
    ERC4626Mock internal newExternalVault;
    ERC4626Escrow internal newEscrow;
    uint256 constant ASSET_AMOUNT = 1e18;
    uint256 assetTokenAmount;
    uint256 shares;
    uint256 ebtcAmount;

    /**
     * @notice Pranks the following call as techOpsMultisig
     * @dev Hevm does not allow the usage of startPrank, this was created 
     * to be used in the wrapper methods that need to be called by this user
     */
    modifier prankTechOpsMultisig() {
        vm.prank(techOpsMultisig);
        _;
    }

    function setUp() public virtual override {
        super.setUp();

        newExternalVault = new ERC4626Mock(address(mockAssetToken));
        newEscrow = new ERC4626Escrow(
            address(newExternalVault),
            address(bsmTester.ASSET_TOKEN()),
            address(bsmTester),
            address(bsmTester.authority()),
            address(escrow.FEE_RECIPIENT())
        );
        
        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(newEscrow));

        setRoleCapability(
            15,
            address(newEscrow),
            newEscrow.claimProfit.selector,
            true
        );
        setRoleCapability(
            15,
            address(newEscrow),
            newEscrow.depositToExternalVault.selector,
            true
        );

        setRoleCapability(
            15,
            address(newEscrow),
            newEscrow.redeemFromExternalVault.selector,
            true
        );

        uint256 numTokens = bound(ASSET_AMOUNT, 1, 1000000000);
        ebtcAmount = _getEbtcAmount(numTokens) * 1e18 / _assetTokenPrecision();
        assetTokenAmount = _getAssetTokenAmount(numTokens);
        shares = newExternalVault.previewDeposit(assetTokenAmount);
        _mintAssetToken(techOpsMultisig, assetTokenAmount);
        
        vm.prank(techOpsMultisig);
        mockAssetToken.approve(address(bsmTester), type(uint256).max);
    }
    
    function testBasicExternalDeposit() public {
        uint256 beforeExternalVaultBalance = mockAssetToken.balanceOf(address(newExternalVault));
        uint256 beforeBalance = mockAssetToken.balanceOf(techOpsMultisig);
        uint256 beforeShares = newExternalVault.balanceOf(address(newEscrow));

        sellAsset();

        uint256 beforeDepositAmount = newEscrow.totalAssetsDeposited();
        uint256 beforeTotalBalance = newEscrow.totalBalance();
        depositToExternalVault(assetTokenAmount, shares);

        uint256 afterExternalVaultBalance = mockAssetToken.balanceOf(address(newExternalVault));
        uint256 afterBalance = mockAssetToken.balanceOf(techOpsMultisig);
        uint256 afterShares = newExternalVault.balanceOf(address(newEscrow));
        uint256 afterDepositAmount = newEscrow.totalAssetsDeposited();
        uint256 afterTotalBalance = newEscrow.totalBalance();

        assertGt(afterExternalVaultBalance, beforeExternalVaultBalance);
        assertGt(beforeBalance, afterBalance);
        assertEq(beforeShares, 0);
        assertEq(afterShares, shares);
        assertEq(beforeDepositAmount, afterDepositAmount);
        assertEq(beforeTotalBalance, afterTotalBalance);
    }
    
    function testBasicExternalRedeem() public {
        sellAsset();
        depositToExternalVault(assetTokenAmount, shares);

        uint256 beforeExternalVaultBalance = mockAssetToken.balanceOf(address(newExternalVault));
        uint256 beforeBalance = mockAssetToken.balanceOf(techOpsMultisig);
        uint256 beforeShares = newExternalVault.balanceOf(address(newEscrow));
        uint256 beforeDepositAmount = newEscrow.totalAssetsDeposited();
        uint256 assets = newExternalVault.previewRedeem(shares);
        uint256 beforeTotalBalance = newEscrow.totalBalance();

        redeemFromExternalVault(shares, assets);

        uint256 afterExternalVaultBalance = mockAssetToken.balanceOf(address(newExternalVault));
        uint256 afterBalance = mockAssetToken.balanceOf(techOpsMultisig);
        uint256 afterShares = newExternalVault.balanceOf(address(newEscrow));
        uint256 afterDepositAmount = newEscrow.totalAssetsDeposited();
        uint256 afterTotalBalance = newEscrow.totalBalance();

        assertGt(beforeExternalVaultBalance, afterExternalVaultBalance);
        assertEq(beforeBalance, afterBalance);
        assertEq(beforeShares, shares);
        assertEq(afterShares, 0);
        assertEq(beforeDepositAmount, afterDepositAmount);
        assertEq(beforeTotalBalance, afterTotalBalance);
    }

    function testPartialExternalRedeem() public {
        sellAsset();
        depositToExternalVault(assetTokenAmount, shares);

        uint256 beforeExternalVaultBalance = mockAssetToken.balanceOf(address(newExternalVault));
        uint256 beforeBalance = mockAssetToken.balanceOf(techOpsMultisig);
        uint256 beforeShares = newExternalVault.balanceOf(address(newEscrow));

        uint256 assets = newExternalVault.previewRedeem(shares);
        redeemFromExternalVault(shares / 2, assets / 2);
        
        uint256 afterExternalVaultBalance = mockAssetToken.balanceOf(address(newExternalVault));
        uint256 afterBalance = mockAssetToken.balanceOf(techOpsMultisig);
        uint256 afterShares = newExternalVault.balanceOf(address(newEscrow));
        
        assertGt(beforeExternalVaultBalance, afterExternalVaultBalance);
        assertEq(beforeBalance, afterBalance);
        assertEq(afterShares, shares / 2);
    }
    
    function testInvalidExternalRedeem() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        newEscrow.redeemFromExternalVault(1e18, 1);

        // Redeem before making deposit
        vm.expectRevert();
        redeemFromExternalVault(1e18, 1);

        sellAsset();

        depositToExternalVault(assetTokenAmount, shares);

        uint256 assets = newExternalVault.previewRedeem(shares);
        vm.expectRevert(abi.encodeWithSelector(ERC4626Escrow.TooFewAssetsReceived.selector, assets + 1, assets));
        redeemFromExternalVault(shares, assets + 1);
    }

    function testInvalidExternalDeposit() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        newEscrow.depositToExternalVault(1e18, 1);
        
        //invalid asset amount sent
        vm.expectRevert(abi.encodeWithSelector(ERC4626Escrow.TooFewSharesReceived.selector, 1, 0));
        depositToExternalVault(0, 1);

        shares = newExternalVault.previewDeposit(ASSET_AMOUNT);
        //invalid expected shares amount
        _mintAssetToken(techOpsMultisig, ASSET_AMOUNT);
        vm.prank(techOpsMultisig);
        bsmTester.sellAsset(ASSET_AMOUNT, address(this), 0);

        vm.expectRevert(abi.encodeWithSelector(ERC4626Escrow.TooFewSharesReceived.selector, shares + 1, shares));
        depositToExternalVault(ASSET_AMOUNT, shares + 1);
    }

    function testExternalVaultLossFailsSlippageCheck() public {
        sellAsset();

        depositToExternalVault(assetTokenAmount, 0);

        uint256 halfAssetAmount = assetTokenAmount / 2;
        // 50% external vault loss
        vm.prank(address(newExternalVault));
        mockAssetToken.transfer(vm.addr(0xdead), halfAssetAmount);
        
        // revert with 50% loss
        _mintEbtc(testBuyer, ebtcAmount);
        uint256 assetAmount = assetTokenAmount * _assetTokenPrecision() / 1e18;
        uint redeemAmount = bsmTester.escrow().previewWithdraw(assetAmount);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.BelowExpectedMinOutAmount.selector, assetTokenAmount, redeemAmount));
        vm.prank(testBuyer);
        bsmTester.buyAsset(assetTokenAmount, testBuyer, assetTokenAmount);

        assertEq(bsmTester.previewBuyAsset(assetTokenAmount), redeemAmount);

        vm.prank(testBuyer);
        assertEq(bsmTester.buyAsset(assetTokenAmount, testBuyer, redeemAmount), redeemAmount);
    }

    function sellAsset() internal prankTechOpsMultisig {
        bsmTester.sellAsset(assetTokenAmount, address(this), 0);
    }

    function depositToExternalVault(uint256 _assetsToDeposit, uint256 _minShares) internal prankTechOpsMultisig {
        newEscrow.depositToExternalVault(_assetsToDeposit, _minShares);
    }

    function redeemFromExternalVault(uint256 _shares, uint256 _assets) internal prankTechOpsMultisig {
        newEscrow.redeemFromExternalVault(_shares, _assets);
    }

}