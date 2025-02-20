// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {OpType, BeforeAfter} from "./BeforeAfter.sol";

abstract contract Properties is BeforeAfter, Asserts {
    function property_accounting_is_sound() public {
        gte(
            escrow.totalBalance(),
            escrow.totalAssetsDeposited(),
            "Total balance is always greater than totalAssetsDeposited"
        );
    }

    function property_accounting_of_profit_is_sound() public {
        gte(escrow.totalBalance(), escrow.feeProfit(), "Total Balance is always greater than profit");
    }

    function property_fees_profit_increases() public {
        if (currentOperation != OpType.CLAIM && currentOperation != OpType.MIGRATE) {
            // any other operation should increase the profit or stay the same
            gte(_after.feesProfit, _before.feesProfit, "Profit should only increase");
        }
    }

    function property_assets_are_not_lost() public {
        if (
            currentOperation != OpType.MIGRATE && currentOperation != OpType.CLAIM
                && currentOperation != OpType.BUY_ASSET_WITH_EBTC
        ) {
            // NOTE: Migration can cause reduction of total balance, since it claims fees
            // NOTE: You can use `netTotalBalance` to ensure the property is always correct
            gte(_after.totalBalance, _before.totalBalance, "Assets should not be lost");
        }
    }

    // Separate property for net balance
    function property_assets_are_not_lost_net() public {
        if (currentOperation != OpType.CLAIM && currentOperation != OpType.BUY_ASSET_WITH_EBTC) {
            gte(_after.netTotalBalance, _before.netTotalBalance, "Assets should not be lost in net terms");
        }
    }
}
