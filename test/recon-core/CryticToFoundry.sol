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

// forge test --match-test test_doomsday_bsmTester_updateEscrow_always_works_0 -vvv 
function test_doomsday_bsmTester_updateEscrow_always_works_0() public {

    bsmTester_sellAsset(3);

        switch_asset(1);

        asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1,1);

    console2.log("escrow.totalBalance()", escrow.totalBalance());
    console2.log("escrow.totalAssetsDeposited()", escrow.totalAssetsDeposited());

    escrow_depositToExternalVault_rekt(3,0);

    bsmTester_updateEscrow_always_works();

    }

    // forge test --match-test test_property_accounting_is_sound_0 -vvv 
    function test_property_accounting_is_sound_0() public {

    bsmTester_sellAsset(1);

        switch_asset(1);

        asset_mint(0xc7183455a4C133Ae270771860664b6B7ec320bB1,1);

    escrow_depositToExternalVault_rekt(1,0);

        property_accounting_is_sound();

    }

    // forge test --match-test test_inlined_withdrawProfitTest_1 -vvv 
    function test_inlined_withdrawProfitTest_1() public {

    bsmTester_sellAsset(1);

    escrow_depositToExternalVault_rekt(1,0);

    bsmTester_updateEscrow();

        inlined_withdrawProfitTest();

    }

}
