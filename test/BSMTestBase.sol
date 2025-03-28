// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
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
        assertEq(bsmTester.totalMinted(), escrow.totalAssetsDeposited() * 1e18 / (10 ** mockAssetToken.decimals()));
    }

    function setUp() public virtual {
        BSMBase.baseSetup(NUM_DECIMALS);
    }
}
