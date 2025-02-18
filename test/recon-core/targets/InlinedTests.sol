// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract InlinedTests is BaseTargetFunctions, Properties {
    modifier stateless() {
        _;
        revert("stateless");
    }



    function doomsday_claimProfit_never_reverts() public stateless asTechops {
        try escrow.claimProfit() {
            /// @audit prob missing the loss on withdrwa, which is something that can happen
        } catch {
            t(false, "doomsday_claimProfit_never_reverts");
        }
    }




    // // TODO: Something about fee and migration
    // function doomsday_updateEscrow(address newEscrow) public stateless asTechops {
    //     // TODO: Deploy new escrow that is legitimate and then try migrating
    //     try bsmTester.updateEscrow(newEscrow) {

    //     } catch {

    //     }

    // }

    // == BASIC STUFF == //
    function escrow_onDeposit(uint256 assetAmount) public stateless asActor {
        escrow.onDeposit(assetAmount);
        t(false, "always fail");
    }

    function escrow_onWithdraw(uint256 assetAmount) public stateless asActor {
        escrow.onWithdraw(assetAmount);
        t(false, "always fail");
    }
        // TODO: Revert always
    function escrow_onMigrateSource(address newEscrow) public stateless asActor {
        escrow.onMigrateSource(newEscrow);
        t(false, "always fail");
    }
}
