// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

interface IEscrow {
    event ProfitClaimed(uint256 profitAmount);

    function totalAssetsDeposited() external view returns (uint256);
    function totalBalance() external view returns (uint256);
    function onDeposit(uint256 assetAmount) external;
    function onWithdraw(uint256 assetAmount) external returns (uint256);
    function previewWithdraw(uint256 assetAmount) external view returns (uint256);
    function claimProfit() external;
    function onMigrateSource(address newEscrow) external;
    function onMigrateTarget(uint256 amount) external;
}
