# eBTC Stability Module

## Table of Contents
- [Overview](#overview)
    - [Escrow](#escrow)
    - [Fee Mechanism](#fee-mechanism)
    - [Oracle Constraint](#oracle-constraint)
    - [Rate Limiting Constraint](#rate-limiting-constraint)
- [Build](#build)
    - [Unit Tests](#unit-tests)
    - [Echidna Tests](#echidna-tests)
    - [Medusa Tests](#medusa-tests)
- [Considerations around admin mistakes](#considerations-around-admin-mistakes)
- [Intgration Targets](#integration-targets)
- [Known issues](#known-issues)

## Overview

The BSM contract facilitates bi-directional exchange between eBTC and other BTC-denominated assets with no slippage. 

## Escrow

The BSM uses escrows to make the architecture more modular. This modular design allows the BSM to perform external lending by depositing idle assets into various money markets. This external lending capability is controlled through a configurable liquidity buffer (100% buffer maintains full reserves). Any yields generated from these lending activities contribute to protocol revenue, which governance can allocate to incentivize stEBTC.

## Fee Mechanism

The BSM can optionally charge a fee on swap operations. The fee percentage is controlled by governance and is capped at 20%.

## Oracle Constraint

The Oracle Constraint pauses minting if the asset price drops too much relative to eBTC. This check does not apply to eBTC burning because it reduces overall system risk.

## Rate Limiting Constraint

The BSM employs a dynamic rate limiting constraint based on the eBTC total supply TWAP, which restricts the amount of eBTC that can be created through asset deposits. This security feature provides controlled exposure to external assets, protecting the system from potential manipulation.

Alternatively, a static minting constraint can be used if enabled by governance.

## Build

```
forge build
```

## Unit Tests

```
forge test
```

## Echidna Tests

```
echidna . --contract CryticTester --config echidna.yaml --format text --workers 16 --test-limit 1000000
```

Latest available run (can download corpus): https://getrecon.xyz/shares/c2a86867-779e-4707-9447-4bfbc41be0d5

## Medusa Tests

```
medusa fuzz
```

## Considerations around admin mistakes

We expect to preview all transactions

Where possible, slippage checks will be used

Where slippage checks are unavailable, we will perform additional checks in our safe (via multicall)

To simulate a riskier behaviour, invariant tests allow enabling:
https://github.com/ebtc-protocol/ebtc-bsm/blob/eb5b85d28abff44aa9e2340e454fd9c29f9edc7d/test/recon-core/Setup.sol#L19-L20

```solidity
    bool ALLOWS_REKT = bool(true);

```

We show the known issues with this reckless behaviour below

In a production setting, we will either quantify the loss and determine it to be negligible, or we will perform only deposits and withdrawals that wouldn't cause a loss

In case of a marginal loss, we would refund that out of the treasury


## Integration Targets

The ERC4626 of interest are:
- AAVE (via this adapter: https://github.com/aave/Aave-Vault)
- Morpho
- Euler

All these 3 conform to the OpenZeppelin ERC4626 implementation

Due to a non-trivial amount of integration risks, we expect to exclusively integrate with vaults that conform to the OZ ERC4626 implementation


## Known issues

The following are known issues, repros are available in `CoreTrophyToFoundry.sol`

```
forge test --match-contract TrophyToFoundry -vv
```

- Accounting is no longer sound if depositing into an external ERC4626 causes a loss, see: [`test_property_accounting_is_sound_0`](https://github.com/ebtc-protocol/ebtc-bsm/blob/eb5b85d28abff44aa9e2340e454fd9c29f9edc7d/test/recon-core/trophies/CoreTrophyToFoundry.sol#L28-L29)
- Assets can be lost if depositing into an external ERC4626 causes a loss, see [`test_property_assets_are_not_lost_123`](https://github.com/ebtc-protocol/ebtc-bsm/blob/eb5b85d28abff44aa9e2340e454fd9c29f9edc7d/test/recon-core/trophies/CoreTrophyToFoundry.sol#L41-L42)
- Profits can decrease if depositing into an external ERC4626 causes a loss, see [`test_property_fees_profit_increases_3`](https://github.com/ebtc-protocol/ebtc-bsm/blob/eb5b85d28abff44aa9e2340e454fd9c29f9edc7d/test/recon-core/trophies/CoreTrophyToFoundry.sol#L54-L55)

- Withdraw Profit can have 1 share stuck, and the admin can be unable to claim that for a non-trivial amount of time

The property `inlined_withdrawProfitTest` uses the following:
https://github.com/ebtc-protocol/ebtc-bsm/blob/eb5b85d28abff44aa9e2340e454fd9c29f9edc7d/test/recon-core/targets/AdminTargets.sol#L117-L121

```solidity
        // Profit should be 0
        // NOTE: Profit can be unable to withdraw the last share due to rounding errors
        // As such profit doesn't reset to 0, but down to 1 wei of a share
        uint256 maxLoss = escrow.EXTERNAL_VAULT().previewRedeem(1);
        lte(escrow.feeProfit(), maxLoss, "Profit should be 0");
```

Which limits the impact to stuck yield equivalent to 1 wei of ERC4626 share

The trophy [`test_inlined_withdrawProfitTest_1`](https://github.com/ebtc-protocol/ebtc-bsm/blob/eb5b85d28abff44aa9e2340e454fd9c29f9edc7d/test/recon-core/trophies/CoreTrophyToFoundry.sol#L77-L78) highlights a scenario in which some funds are stuck

And `echidna` can be used to reproduce more scenarios

We would highly appreciate flagging losses that reach at least 1 ** decimals of asset, as losses below that would not be worth spending the gas to recoup them