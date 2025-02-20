// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import "forge-std/console2.sol";

enum OpType {
    GENERIC,
    CLAIM, // This op resets the fee
    MIGRATE, // This op migrates the vault and resets the fee
    BUY_ASSET_WITH_EBTC // This op buys underlying asset with eBTC

}

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    struct Vars {
        uint256 feesProfit;
        uint256 totalBalance;
        uint256 netTotalBalance;
    }

    Vars internal _before;
    Vars internal _after;
    OpType internal currentOperation;

    modifier updateGhosts() {
        currentOperation = OpType.GENERIC;
        __before();
        _;
        __after();
    }

    modifier updateGhostsWithType(OpType op) {
        currentOperation = op;
        __before();
        _;
        __after();
    }

    function __before() internal {
        _before.feesProfit = escrow.feeProfit();
        _before.totalBalance = escrow.totalBalance();
        // Safe because: property_accounting_of_profit_is_sound
        _before.netTotalBalance = _before.totalBalance - _before.feesProfit;
    }

    function __after() internal {
        _after.feesProfit = escrow.feeProfit();
        _after.totalBalance = escrow.totalBalance();
        // Safe because: property_accounting_of_profit_is_sound
        _after.netTotalBalance = _after.totalBalance - _after.feesProfit;
    }
}
