// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "./BSMTestBase.sol";
import "../src/RateLimitingConstraint.sol";
import "../src/OraclePriceConstraint.sol";
import "../src/DummyConstraint.sol";

contract GovernanceTests is BSMTestBase {

    function testClaimProfit(uint256 numTokens, uint256 fraction) public {
        (uint256 ebtcAmount, uint256 assetTokenAmount) = _getTestData(numTokens, fraction);
        
        _mintAssetToken(testMinter, assetTokenAmount * 2);
        
        // TEST: auth
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        escrow.claimProfit();

        // TEST: event + accounting
        // 1% fee
        vm.prank(techOpsMultisig);
        bsmTester.setFeeToSell(100);

        uint256 fee = _feeToSell(assetTokenAmount);
        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, 0);
        assertEq(escrow.feeProfit(), fee);
        
        vm.expectEmit(address(escrow));
        emit IEscrow.ProfitClaimed(fee);
        vm.prank(techOpsMultisig);
        escrow.claimProfit();

        assertEq(escrow.feeProfit(), 0);
        
        // TEST: profitWithdraw is not he same as feeProfit
        vm.prank(testMinter);
        bsmTester.sellAsset(assetTokenAmount, testMinter, 0);
        fee = escrow.feeProfit();
        // provoke deficit by removing some asset token
        /*vm.prank(address(escrow));
        mockAssetToken.burn(address(escrow), assetTokenAmount);*/
        console.log("aaaaaaaaaaaaaa");
        vm.expectEmit(address(escrow));
        emit IEscrow.ProfitClaimed(fee);
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
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidFee.selector));
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
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidFee.selector));
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

        // TEST: address(0)
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidAddress.selector));
        vm.prank(techOpsMultisig);
        bsmTester.setOraclePriceConstraint(address(0));

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

        // TEST: address(0)
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidAddress.selector));
        vm.prank(techOpsMultisig);
        bsmTester.setRateLimitingConstraint(address(0));

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

        // TEST: address(0)
        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidAddress.selector));
        vm.prank(techOpsMultisig);
        bsmTester.setBuyAssetConstraint(address(0));

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

        uint256 bps = bsmTester.BPS();

        vm.expectRevert(abi.encodeWithSelector(RateLimitingConstraint.InvalidMintingConfig.selector));
        vm.prank(techOpsMultisig);
        rateLimitingConstraint.setMintingConfig(address(bsmTester), RateLimitingConstraint.MintingConfig(bps + 1, 0, false));    
    }

    function testUpdateEscrow() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        bsmTester.updateEscrow(address(0));

        vm.expectRevert(abi.encodeWithSelector(EbtcBSM.InvalidAddress.selector));
        vm.prank(techOpsMultisig);
        bsmTester.updateEscrow(address(0));
    }

    function testSetMinPrice() public {
        uint256 bps = bsmTester.BPS();

        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        oraclePriceConstraint.setMinPrice(bps);

        vm.expectRevert(abi.encodeWithSelector(OraclePriceConstraint.InvalidMinPrice.selector));
        vm.prank(techOpsMultisig);
        oraclePriceConstraint.setMinPrice(bps + 1);
    }

    function testSetOracleFreshness() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        vm.prank(testMinter);
        oraclePriceConstraint.setOracleFreshness(1000);
    }
}