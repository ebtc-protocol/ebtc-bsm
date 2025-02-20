// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import "forge-std/console2.sol";

import {TargetFunctions} from "./TargetFunctions.sol";

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();

        vm.label(address(mockAssetToken), "mockAssetToken");
        vm.label(address(mockEbtcToken), "mockEbtcToken");
        vm.label(address(second_actor), "second_actor");
        vm.label(address(this), "actor");
        vm.label(address(bsmTester), "bsmTester");
        vm.label(address(techOpsMultisig), "techOpsMultisig");
        vm.label(address(escrow), "escrow");
    }

    // forge test --match-test test_crytic -vvv
    function test_crytic() public {
        bsmTester_updateEscrow();
    }

    // forge test --match-test test_inlined_withdrawProfitTest_3 -vvv 
function test_inlined_withdrawProfitTest_3() public {

    switch_asset(2436602065832982646652471311549243035081923860249);

    asset_mint(0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF,12254642527501096527466605035);

    escrow_depositToExternalVault_rekt(1,0);

    asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1,1734415515435150754529941459);

    inlined_withdrawProfitTest();

 }

    // forge test --match-test test_property_accounting_is_sound_0 -vvv
    function test_property_accounting_is_sound_0() public {
        bsmTester_sellAsset(1);

        switch_asset(1);

        asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1, 1);

        escrow_depositToExternalVault_rekt(1, 0);

        property_accounting_is_sound();
    }

    // forge test --match-test test_property_assets_are_not_lost_123 -vvv
    function test_property_assets_are_not_lost_123() public {
        switch_asset(1);

        asset_mint(0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF, 1);

        asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1, 1);

        escrow_depositToExternalVault_rekt(1, 0);

        property_assets_are_not_lost();
    }

    // forge test --match-test test_property_fees_profit_increases_3 -vvv
    function test_property_fees_profit_increases_3() public {
        switch_asset(1);

        asset_mint(0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF, 1);

        asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1, 1);

        escrow_depositToExternalVault_rekt(1, 0);

        property_fees_profit_increases();
    }


// forge test --match-test test_inlined_withdrawProfitTest_1 -vvv 
function test_inlined_withdrawProfitTest_1() public {

    switch_asset(133967697141585457301717130397693243365160822926910117093032297);
    // 0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF = Escrow
    asset_mint(0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF,784504222176724349469605330757355);

    escrow_depositToExternalVault_rekt(1,0); /// This somehow causes losses
    // 0xc7183455a4C133Ae270771860664b6B7ec320bB1 = ERC4626 Mock
    asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1,1896638755834581645447202929696129);

    // inlined_withdrawProfitTest();
    uint256 amt = escrow.feeProfit();
    uint256 balB4Escrow = escrow.totalBalance();

    // Figure out what we'd get off of liquid balance

    uint256 liquidBal = escrow.ASSET_TOKEN().balanceOf(address(escrow));
    uint256 delta;
    if(amt > liquidBal) {
        uint256 delta = amt - liquidBal;
    } else {
        revert("Not interesting"); // NOTE: Skip cases where yield can be paid from liquid
        // TODO: In those cases we should get the exact value btw
    }

    // Expected lower
    uint256 shares = escrow.EXTERNAL_VAULT().convertToShares(delta);
    uint256 expected = escrow.EXTERNAL_VAULT().previewRedeem(shares) + liquidBal;

    console2.log("amt", amt);
    console2.log("balB4Escrow", balB4Escrow);
    console2.log("shares", shares);
    console2.log("expected", expected);

    uint256 balB4 = (escrow.ASSET_TOKEN()).balanceOf(address(escrow.FEE_RECIPIENT()));
    escrow_claimProfit();
    /// TODO: CHECK THIS BETTER, Something is off in the logic
    uint256 balAfter = (escrow.ASSET_TOKEN()).balanceOf(address(escrow.FEE_RECIPIENT()));

    // The test is a bound as some slippage loss can happen, we take the worst slippage and the exact amt and check against those
    uint256 deltaFees = balAfter - balB4;

    // NOTE: Since expected is the product of 2 round downs, we should receive more due to rounding
    // Also: The test assumes all profit is off of the shares
    // But in reality you can have profit from donations
    // As such we perform this clamped check
    gte(deltaFees, expected, "Recipient got at least expected");
    lte(deltaFees, amt, "Delta fees is at most profit");

    // Total Balance of Vualt should also move correctly
    gte(escrow.totalBalance(), balB4Escrow - amt, "Escrow balance decreases at most by profit");
    lte(escrow.totalBalance(), balB4Escrow - expected, "Escrow balance decreases at least by expected");

    // Profit should be 0
    eq(escrow.feeProfit(), 0, "Profit should be 0"); // NOTE: WTF ???

 }

 // forge test --match-test test_inlined_withdrawProfitTest_5 -vvv 
function test_inlined_withdrawProfitTest_5() public {

    switch_asset(18199351719602885449076422830520787782474470306376559297422219);

    asset_mint(0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF,196455345008010007563393732391);

    escrow_depositToExternalVault_rekt(1,0);

    asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1,1896638755834581645447202929696129);

    console2.log("escrow.feeProfit()", escrow.feeProfit());
    escrow_claimProfit();
    console2.log("escrow.feeProfit()", escrow.feeProfit());
    escrow_claimProfit();
    console2.log("escrow.feeProfit()", escrow.feeProfit());
    escrow_claimProfit();
    console2.log("escrow.feeProfit()", escrow.feeProfit());
    escrow_claimProfit();
    console2.log("escrow.feeProfit()", escrow.feeProfit());
    inlined_withdrawProfitTest();

 }
}
