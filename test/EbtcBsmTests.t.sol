// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "./BSMTestBase.sol";
import "../src/DummyConstraint.sol";
import "./mocks/MockAssetToken.sol";

contract EbtcBSMTests is BSMTestBase {
    //forge test --match-test "testCorrectConstructorValues" --verbosity -v
    function testCorrectConstructorValues() public {
        DummyConstraint dummy = new DummyConstraint();
        vm.expectRevert();
        EbtcBSM bsm = new EbtcBSM(
            address(0),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(dummy),
            address(mockEbtcToken),
            address(authority)
        );

        vm.expectRevert();
        bsm = new EbtcBSM(
            address(mockAssetToken),
            address(0),
            address(rateLimitingConstraint),
            address(dummy),
            address(mockEbtcToken),
            address(authority)
        );

        vm.expectRevert();
        bsm = new EbtcBSM(
            address(mockAssetToken),
            address(oraclePriceConstraint),
            address(0),
            address(dummy),
            address(mockEbtcToken),
            address(authority)
        );

        vm.expectRevert();
        bsm = new EbtcBSM(
            address(mockAssetToken),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(0),
            address(mockEbtcToken),
            address(authority)
        );

        vm.expectRevert();
        bsm = new EbtcBSM(
            address(mockAssetToken),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(dummy),
            address(0),
            address(authority)
        );

        vm.expectRevert();
        bsm = new EbtcBSM(
            address(mockAssetToken),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(dummy),
            address(mockEbtcToken),
            address(0)
        );

        MockAssetToken wrongToken = new MockAssetToken(19);
        vm.expectRevert();
        bsm = new EbtcBSM(
            address(wrongToken),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(dummy),
            address(mockEbtcToken),
            address(authority)
        );
    }

    function testCorrectInitializationValue() public {
        EbtcBSM bsm = new EbtcBSM(
            address(mockAssetToken),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(new DummyConstraint()),
            address(mockEbtcToken),
            address(authority)
        );

        vm.expectRevert();
        bsmTester.initialize(address(0));
    }

    function testBuyZeroAmount() public {
        MockAssetToken wrongToken = new MockAssetToken(6);
        EbtcBSM bsm = new EbtcBSM(
            address(wrongToken),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(new DummyConstraint()),
            address(mockEbtcToken),
            address(authority)
        );
        vm.prank(testMinter);
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.ZeroAmount.selector));
        bsm.buyAsset(1, testMinter, 2);
    }
}