// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./BSMTestBase.sol";
import "./mocks/MockAssetToken.sol";

contract EscrowTests is BSMTestBase {
    MockAssetToken internal mockToken;
    uint256 amount = 1e18;

    function setUp() public virtual override {
        super.setUp();
        mockToken = new MockAssetToken(18);
        
        // Sending tokens
        mockToken.mint(address(escrow), amount);
        assertEq(mockToken.balanceOf(address(escrow)), amount);
    }

    function testClaimTokens() public {
        // if invalid tokens
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        escrow.claimTokens(address(mockAssetToken), 1);// asset token

        address vaultAddress = address(escrow.EXTERNAL_VAULT());
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        escrow.claimTokens(vaultAddress, 1);// vault token

        // if no authorized user
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        escrow.claimTokens(address(mockToken), amount);

        // if no token in contract
        MockAssetToken diffToken = new MockAssetToken(18);
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        escrow.claimTokens(address(diffToken), amount);

        // Try to withdraw greater amount
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        escrow.claimTokens(address(mockToken), amount * 2);
        assertEq(mockToken.balanceOf(escrow.FEE_RECIPIENT()), 0);

        // if amount = 0
        vm.prank(techOpsMultisig);
        escrow.claimTokens(address(mockToken), 0);
        assertEq(mockToken.balanceOf(address(escrow)), amount);
        assertEq(mockToken.balanceOf(escrow.FEE_RECIPIENT()), 0);

        // Happy path
        vm.prank(techOpsMultisig);
        escrow.claimTokens(address(mockToken), amount);
        assertEq(mockToken.balanceOf(address(escrow)), 0);
        assertEq(mockToken.balanceOf(escrow.FEE_RECIPIENT()), amount);
    }
}