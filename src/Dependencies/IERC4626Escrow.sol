// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import {IEscrow} from "./IEscrow.sol";

interface IERC4626Escrow is IEscrow {
    function depositToExternalVault(uint256 assetsToDeposit, uint256 minShares) external;
    function redeemFromExternalVault(uint256 sharesToRedeem, uint256 minAssets) external;
}
