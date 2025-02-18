// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {OpType, BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";
import "../../../src/ERC4626Escrow.sol";
import {RateLimitingConstraint} from "../../../src/RateLimitingConstraint.sol";

contract MockAlwaysTrueAuthority {
    function canCall(address user, address target, bytes4 functionSig) external view returns (bool) {
        return true;
    }
}


abstract contract AdminTargets is BaseTargetFunctions, Properties {

    /// === Escrow === ///
    function escrow_depositToExternalVault_rekt(uint256 assetsToDeposit, uint256 expectedShares) public updateGhosts asTechops {
        require(ALLOWS_REKT, "Allows rekt");
        escrow.depositToExternalVault(assetsToDeposit, expectedShares);
    }
    /// === Escrow === ///
    function escrow_depositToExternalVault_not_rekt(uint256 assetsToDeposit, uint256 expectedShares) public updateGhosts {
        require(!ALLOWS_REKT, "Must not allow rekt");

        uint256 balanceB4 = escrow.totalBalance();

        // asTechops
        vm.prank(address(techOpsMultisig));
        escrow.depositToExternalVault(assetsToDeposit, expectedShares);

        uint256 balanceAfter = escrow.totalBalance();

        require(balanceAfter >= balanceB4, "Prevent Self Rekt");
    }

    function escrow_redeemFromExternalVault(uint256 sharesToRedeem, uint256 expectedAssets) public updateGhosts asTechops {
        escrow.redeemFromExternalVault(sharesToRedeem, expectedAssets);
    }

    function escrow_onMigrateTarget(uint256 amount) public updateGhosts asTechops {
        escrow.onMigrateTarget(amount);
    }

    function escrow_claimProfit() public updateGhosts asTechops {
        escrow.claimProfit();
    }

    function inlined_withdrawProfitTest() public {
        uint256 amt = escrow.feeProfit();
        uint256 balB4Escrow = escrow.totalBalance();

        // Expected lower
        uint256 shares = escrow.EXTERNAL_VAULT().convertToShares(amt);
        uint256 expected = escrow.EXTERNAL_VAULT().previewRedeem(shares);

        uint256 balB4 = (escrow.ASSET_TOKEN()).balanceOf(address(escrow.FEE_RECIPIENT()));
        escrow_claimProfit(); // The estimate should be 
        uint256 balAfter = (escrow.ASSET_TOKEN()).balanceOf(address(escrow.FEE_RECIPIENT()));

        // The test is a bound as some slippage loss can happen, we take the worst slippage and the exact amt and check against those
        uint256 deltaFees = balAfter - balB4;

        gte(expected, deltaFees, "Recipien got at least expected");
        lte(deltaFees, amt, "Delta fees is at most profit");

        // Total Balance of Vualt should also move correctly
        gte(escrow.totalBalance(), balB4Escrow - amt, "Escrow balance decreases at most by profit");
        lte(escrow.totalBalance(), balB4Escrow - expected, "Escrow balance decreases at least by expected");

        // Profit should be 0
        // eq(escrow.feeProfit(), 0, "Profit should be 0"); /// @audit is it ok for it to be non-zero?
    }

    

    /// === BSM === ///
    function bsmTester_pause() public updateGhosts asTechops {
        bsmTester.pause();
    }

    function bsmTester_setFeeToBuy(uint256 _feeToBuyAssetBPS) public updateGhosts asTechops {
        bsmTester.setFeeToBuy(_feeToBuyAssetBPS);
    }

    function bsmTester_setFeeToSell(uint256 _feeToBuyEbtcBPS) public updateGhosts asTechops {
        bsmTester.setFeeToSell(_feeToBuyEbtcBPS);
    }

    function bsmTester_setMintingConfig(uint256 _mintingCapBPS) public updateGhosts asTechops {
        rateLimitingConstraint.setMintingConfig(address(bsmTester), RateLimitingConstraint.MintingConfig(_mintingCapBPS, 0, false));
    }

    function bsmTester_unpause() public updateGhosts asTechops {
        bsmTester.unpause();
    }

    // Custom handler
    function bsmTester_updateEscrow() public updateGhosts {
        // Replace
        escrow = new ERC4626Escrow(
            address(externalVault),
            address(mockAssetToken),
            address(bsmTester),
            address(new MockAlwaysTrueAuthority()),
            escrow.FEE_RECIPIENT()
        );

        uint256 balB4 = (escrow.ASSET_TOKEN()).balanceOf(address(escrow.FEE_RECIPIENT()));
        
        vm.prank(address(techOpsMultisig));
        bsmTester.updateEscrow(address(escrow));
    }
    
    // Stateless test
    /// @dev maybe the name is too long for medusa?
 /*   function doomsday_bsmTester_updateEscrow_always_works() public {
        try this.bsmTester_updateEscrow() {

        } catch {
            t(false, "doomsday_bsmTester_updateEscrow_always_works");
        }

        revert("stateless");
    }  */

    function bsmTester_updateEscrow_always_works() public {
        try this.bsmTester_updateEscrow() {

        } catch {
            t(false, "doomsday_bsmTester_updateEscrow_always_works");
        }

        revert("stateless");
    } 
}
