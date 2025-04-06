// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BSMBase} from "./BSMBase.sol";
import "../src/EbtcBSM.sol";

contract BSMTestBase is BSMBase, Test {
    function testBsmCannotBeReinitialize() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        bsmTester.initialize(address(escrow));
    }

    function _checkAssetTokenBalance(address addr, uint256 amount) internal {
        assertEq(mockAssetToken.balanceOf(addr), amount);
    }

    function _checkEbtcBalance(address addr, uint256 amount) internal {
        assertEq(mockEbtcToken.balanceOf(addr), amount);
    }

    function _totalMintedEqTotalAssetsDeposited() internal {
        assertEq(bsmTester.totalMinted(), escrow.totalAssetsDeposited() * 1e18 / _assetTokenPrecision());
    }

    function _getTestData(uint256 numTokens, uint256 fraction) internal returns(uint256 ebtcAmount, uint256 assetTokenAmount) {
        numTokens = bound(numTokens, 1, 1000000000);
        fraction = bound(fraction, 0, _assetTokenPrecision());
        ebtcAmount = _getEbtcAmount(numTokens) + fraction * 1e18 / _assetTokenPrecision();
        assetTokenAmount = _getAssetTokenAmount(numTokens) + fraction;
    }

    function _feeToBuy(uint256 amount) internal view returns (uint256) {
        uint256 feeAmount = Math.mulDiv(amount, bsmTester.feeToBuyBPS(), bsmTester.BPS(), Math.Rounding.Ceil);
        return feeAmount * _assetTokenPrecision() / 1e18;
    }

    function _feeToSell(uint256 amount) internal view returns (uint256) {
        return Math.mulDiv(
            amount, bsmTester.feeToSellBPS(), 
            bsmTester.feeToSellBPS() + bsmTester.BPS(),
            Math.Rounding.Ceil
        );
    }

    function setUp() public virtual {
        BSMBase.baseSetup(NUM_DECIMALS);
    }
}
