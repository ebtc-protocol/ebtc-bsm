// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./BSMTestBase.sol";
import "./mocks/MockAssetToken.sol";

contract EscrowTests is BSMTestBase {
    MockAssetToken internal mockToken;

    function setUp() public virtual override {
        super.setUp();
        mockToken = new MockAssetToken(18);
        
        // Sending tokens
        mockToken.mint(address(escrow), amount);
        assertEq(mockToken.balanceOf(address(escrow)), amount);
    }

    function testClaimToken() public {
        uint256 amount = 1e18;
        // if invalid token
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        escrow.claimToken(address(mockAssetToken), 1);

        // if no authorized user
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        escrow.claimToken(address(mockToken), amount);

        // if no token in contract
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        escrow.claimToken(address(mockToken), amount);

        // Try to withdraw greater amount
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        escrow.claimToken(address(mockToken), amount * 2);
        assertEq(mockToken.balanceOf(escrow.FEE_RECIPIENT()), 0);

        // if amount = 0
        vm.prank(techOpsMultisig);
        escrow.claimToken(address(mockToken), 0);
        assertEq(mockToken.balanceOf(address(escrow)), amount);
        assertEq(mockToken.balanceOf(escrow.FEE_RECIPIENT()), 0);

        // Happy path
        vm.prank(techOpsMultisig);
        escrow.claimToken(address(mockToken), amount);
        assertEq(mockToken.balanceOf(address(escrow)), 0);
        assertEq(mockToken.balanceOf(escrow.FEE_RECIPIENT()), amount);
    }
}