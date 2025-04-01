// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "./BSMTestBase.sol";
import "../src/RateLimitingConstraint.sol";
import "../src/OraclePriceConstraint.sol";
import "../src/DummyConstraint.sol";

contract GovernanceTests is BSMTestBase {

    function testClaimProfit() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        escrow.claimProfit();

        vm.prank(techOpsMultisig);
        escrow.claimProfit();
    }

    function testSetFeeToBuy() public {
        // TEST: auth
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.setFeeToBuy(1);

        // TEST: can't set above max fee
        uint256 maxFee = bsmTester.MAX_FEE();
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToBuy(maxFee + 1);

        // TEST: event
        uint256 oldFee = bsmTester.feeToBuyBPS();
        vm.expectEmit(address(bsmTester));
        emit IEbtcBSM.FeeToBuyUpdated(oldFee, maxFee);
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToBuy(maxFee);
    }

    function testSetFeeToSell() public {
        // TEST: auth
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.setFeeToSell(1);

        // TEST: can't set above max fee
        uint256 maxFee = bsmTester.MAX_FEE();
        vm.expectRevert();
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(maxFee + 1);

        // TEST: event
        uint256 oldFee = bsmTester.feeToSellBPS();
        vm.expectEmit(address(bsmTester));
        emit IEbtcBSM.FeeToSellUpdated(oldFee, maxFee);
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(maxFee);
    }

    function testSetOraclePriceConstraint() public {
        OraclePriceConstraint newConstraint = new OraclePriceConstraint(
            address(mockAssetOracle),
            address(authority)
        );

        // TEST: auth
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.setOraclePriceConstraint(address(newConstraint));

        // TEST: successfully setting constraint + event
        assertNotEq(address(bsmTester.oraclePriceConstraint()), address(newConstraint));
        address oldConstraint = address(bsmTester.oraclePriceConstraint());
        vm.expectEmit(address(bsmTester));
        emit IConstraint.ConstraintUpdated(oldConstraint, address(newConstraint));
        vm.prank(techOpsMultisig);
        bsmTester.setOraclePriceConstraint(address(newConstraint));
        assertEq(address(bsmTester.oraclePriceConstraint()), address(newConstraint));
    }

    function testSetRateLimitingConstraint() public {
        RateLimitingConstraint newConstraint = new RateLimitingConstraint(
            address(mockActivePoolObserver),
            address(authority)
        );

        // TEST: auth
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.setRateLimitingConstraint(address(newConstraint));

        // TEST: successfully setting constraint + event
        assertNotEq(address(bsmTester.rateLimitingConstraint()), address(newConstraint));
        address oldConstraint = address(bsmTester.rateLimitingConstraint());
        vm.expectEmit(address(bsmTester));
        emit IConstraint.ConstraintUpdated(oldConstraint, address(newConstraint));
        vm.prank(techOpsMultisig);
        bsmTester.setRateLimitingConstraint(address(newConstraint));
        assertEq(address(bsmTester.rateLimitingConstraint()), address(newConstraint));
    }

    function testSetBuyAssetConstraint() public  {
        DummyConstraint newConstraint = new DummyConstraint();

        // TEST: auth
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.setBuyAssetConstraint(address(newConstraint));

        // TEST: successfully setting constraint + event
        assertNotEq(address(bsmTester.buyAssetConstraint()), address(newConstraint));
        address oldConstraint = address(bsmTester.buyAssetConstraint());
        vm.expectEmit(address(bsmTester));
        emit IConstraint.ConstraintUpdated(oldConstraint, address(newConstraint));
        vm.prank(techOpsMultisig);
        bsmTester.setBuyAssetConstraint(address(newConstraint));
        assertEq(address(bsmTester.buyAssetConstraint()), address(newConstraint));
    }

    function testSetMintingConfig() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        rateLimitingConstraint.setMintingConfig(address(bsmTester), RateLimitingConstraint.MintingConfig(0, 0, false));
    }

    function testUpdateEscrow() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.updateEscrow(address(0));
    }

    function testSetMinPrice() public {
        uint256 bps = bsmTester.BPS();

        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        oraclePriceConstraint.setMinPrice(bps);

        vm.expectRevert();
        vm.prank(techOpsMultisig);
        oraclePriceConstraint.setMinPrice(bps + 1);
    }

    function testSetOracleFreshness() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        oraclePriceConstraint.setOracleFreshness(1000);
    }
}