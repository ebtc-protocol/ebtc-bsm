// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import { AuthNoOwner } from "./Dependencies/AuthNoOwner.sol";
import { IEscrow } from "./Dependencies/IEscrow.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title BaseEscrow
/// @notice Handles assets custody on deposits and withdrawals.
contract BaseEscrow is AuthNoOwner, IEscrow {
    using SafeERC20 for IERC20;

    IERC20 public immutable ASSET_TOKEN;
    address public immutable BSM;
    address public immutable FEE_RECIPIENT;

    /// @notice total user deposit amount
    uint256 public totalAssetsDeposited;

    error CallerNotBSM();

    /// @notice Modifier to restrict function calls to the BSM
    modifier onlyBSM() {
        if (msg.sender != BSM) {
            revert CallerNotBSM();
        }
        _;
    }

    /// @notice Contract constructor
    /// @param _assetToken The ERC20 token address used for deposits and withdrawals
    /// @param _bsm The address of the eBTC Stability Module (BSM)
    /// @param _governance The governance address used for AuthNoOwner
    /// @param _feeRecipient The address where collected fees are sent
    constructor(address _assetToken, address _bsm, address _governance, address _feeRecipient) {
        ASSET_TOKEN = IERC20(_assetToken);
        BSM = _bsm;
        FEE_RECIPIENT = _feeRecipient;
        _initializeAuthority(_governance);

        // allow the BSM to transfer asset tokens
        ASSET_TOKEN.approve(BSM, type(uint256).max);
    }

    /// @dev Internal function that checks the total balance of assets held by the contract
    function _totalBalance() internal virtual view returns (uint256) {
        return ASSET_TOKEN.balanceOf(address(this));
    }

    /// @notice Internal function to handle asset deposits
    /// @param _assetAmount The amount of assets to deposit
    function _onDeposit(uint256 _assetAmount) internal virtual {
        totalAssetsDeposited += _assetAmount;
    }

    /// @notice Internal function to handle asset withdrawals
    /// @param _assetAmount The amount of assets to withdraw
    /// @return The amount of assets actually withdrawn
    function _onWithdraw(uint256 _assetAmount) internal virtual returns (uint256) {
        totalAssetsDeposited -= _assetAmount;
        /// @dev returning the amount requested since this is the base contract
        /// it's possible for other implementations to return lower amounts
        return _assetAmount;
    }

    /// @notice Internal function to preview the withdrawable amount without making any state changes
    /// @param _assetAmount The amount of assets queried for withdrawal
    /// @return The amount that can be withdrawn
    function _previewWithdraw(uint256 _assetAmount) internal virtual view returns (uint256) {
        return _assetAmount;
    }

    /// @notice withdraw profit to FEE_RECIPIENT
    /// @param _profitAmount The amount of profit to withdraw
    function _withdrawProfit(uint256 _profitAmount) internal virtual {
        ASSET_TOKEN.safeTransfer(FEE_RECIPIENT, _profitAmount);
    }

    /// @notice Prepares the escrow for migration
    function _beforeMigration() internal virtual {
        // Do nothing
    }

    /// @notice Internal function to claim profits generated from fees and external lending
    function _claimProfit() internal {
        uint256 profit = feeProfit();
        if (profit > 0) {
            _withdrawProfit(profit);
            // INVARIANT: total balance must be >= deposit amount
            require(_totalBalance() >= totalAssetsDeposited);
        }        
    }

    /// @notice Returns the total balance of assets in the escrow
    function totalBalance() external view returns (uint256) {
        return _totalBalance();
    }

    /// @notice Deposits assets into the escrow
    /// @dev Can only be called by the bsm contract
    /// @param _assetAmount The amount of assets to deposit
    function onDeposit(uint256 _assetAmount) external onlyBSM {
        _onDeposit(_assetAmount);
    }

    /// @notice Withdraws assets from the escrow
    /// @dev Can only be called by the bsm contract
    /// @param _assetAmount The amount of assets to withdraw
    /// @return The amount of assets withdrawn
    function onWithdraw(uint256 _assetAmount) external onlyBSM returns (uint256) {
        return _onWithdraw(_assetAmount);
    }

    function previewWithdraw(uint256 _assetAmount) external view returns (uint256) {
        return _previewWithdraw(_assetAmount);
    }

    /// @notice Called on the source escrow during a migration by the BSM to transfer liquidity
    /// @dev Can only be called by the bsm contract
    /// @param _newEscrow new escrow address
    function onMigrateSource(address _newEscrow) external onlyBSM {
        /// @dev take profit first (totalBalance == depositAmount after)
        _claimProfit();

        /// @dev clear depositAmount in old vault (address(this))
        totalAssetsDeposited = 0;

        /// @dev perform pre-migration tasks (potentially used by derived contracts)
        _beforeMigration();

        /// @dev transfer all liquidity to new vault
        ASSET_TOKEN.safeTransfer(_newEscrow, ASSET_TOKEN.balanceOf(address(this)));
    }

    /// @notice Called on the target escrow during a migration by the BSM to set the user deposit amount
    /// @dev Can only be called by the bsm contract
    function onMigrateTarget(uint256 _amount) external onlyBSM {
        totalAssetsDeposited = _amount;
    }

    /// @notice Calculates the profit generated from asset management
    /// @return The amount of profit generated
    function feeProfit() public view returns (uint256) {
        uint256 tb = _totalBalance();
        if(tb > totalAssetsDeposited) {
            return _totalBalance() - totalAssetsDeposited;
        }

        return 0;
    }

    /// @notice Claim profit (fees + external lending profit)
    /// @dev can only be called by authorized users
    function claimProfit() external requiresAuth {
        _claimProfit();
    }
}
