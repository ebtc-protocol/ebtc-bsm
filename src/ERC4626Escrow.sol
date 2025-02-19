// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {BaseEscrow} from "./BaseEscrow.sol";
import {IERC4626Escrow} from "./Dependencies/IERC4626Escrow.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ERC4626 Escrow Contract
/// @notice This contract extends the BaseEscrow to interact with an ERC4626 compliant external vault for asset management
/// and for additional yield opportunities.
contract ERC4626Escrow is BaseEscrow, IERC4626Escrow {
    using SafeERC20 for IERC20;

    /// @notice Basis points representation for calculations
    uint256 public constant BPS = 10000;

    /// @notice The ERC4626 compliant external vault used
    IERC4626 public immutable EXTERNAL_VAULT;

    /// @notice Error for when fewer shares than expected are received from the external vault
    error TooFewSharesReceived(uint256 minShares, uint256 actualShares);

    /// @notice Error for when fewer assets than expected are received from the external vault
    error TooFewAssetsReceived(uint256 minAssets, uint256 actualAssets);

    /// @notice Constructor for the contract
    /// @param _externalVault The address of the ERC4626 compliant external vault
    /// @param _assetToken The ERC20 token address used for deposits and withdrawals
    /// @param _bsm The address of the BSM
    /// @param _governance The governance address used for AuthNoOwner
    /// @param _feeRecipient The address where collected fees are sent
    constructor(
        address _externalVault,
        address _assetToken,
        address _bsm,
        address _governance,
        address _feeRecipient
    ) BaseEscrow(_assetToken, _bsm, _governance, _feeRecipient) {
        EXTERNAL_VAULT = IERC4626(_externalVault);
    }

    /// @notice Overrides _onWithdraw from BaseEscrow to manage liquidity from the external vault
    /// @param _assetAmount The amount of assets to withdraw
    /// @return redeemedAmount The actual amount of assets redeemed from the vault
    function _onWithdraw(
        uint256 _assetAmount
    ) internal override returns (uint256) {
        uint256 redeemedAmount = _ensureLiquidity(_assetAmount);
        // remove assetAmount from depositAmount even if redeemedAmount < assetAmount
        super._onWithdraw(_assetAmount);
        return redeemedAmount;
    }

    /// @notice Ensures sufficient liquidity is available by redeeming assets from the external vault if necessary
    /// @param _amountRequired The amount of assets required
    /// @return amountRedeemed The actual amount of assets redeemed
    function _ensureLiquidity(uint256 _amountRequired) private returns (uint256 amountRedeemed) {
        /// @dev super._totalBalance() returns asset balance for this contract
        uint256 liquidBalance = super._totalBalance();
        amountRedeemed = _amountRequired;

        if (_amountRequired > liquidBalance) {
            uint256 deficit;
            unchecked {
                deficit = _amountRequired - liquidBalance;
            }
            // using convertToShares here because it rounds down
            // this prevents the vault from taking on losses
            uint256 shares = EXTERNAL_VAULT.convertToShares(deficit);
            uint256 balanceBefore = ASSET_TOKEN.balanceOf(address(this));
            EXTERNAL_VAULT.redeem(shares, address(this), address(this));
            uint256 balanceAfter = ASSET_TOKEN.balanceOf(address(this));
            // amountRedeemed can be less than deficit because of rounding
            amountRedeemed = liquidBalance + (balanceAfter - balanceBefore);
        }
    }

    /// @notice Returns the total balance of assets
    /// @dev Combines local balance with the balance held in the external vault
    /// @return The total balance of assets
    function _totalBalance() internal override view returns (uint256) {
        /// @dev convertToAssets is the same as previewRedeem for OZ, Aave, Euler, Morpho
        return EXTERNAL_VAULT.convertToAssets(EXTERNAL_VAULT.balanceOf(address(this))) + super._totalBalance();
    }

    /// @notice Overrides _withdrawProfit from BaseEscrow to manage liquidity from the external vault
    /// @param _profitAmount The amount of profit to withdraw
    function _withdrawProfit(uint256 _profitAmount) internal override {
        uint256 redeemedAmount = _ensureLiquidity(_profitAmount);
        super._withdrawProfit(redeemedAmount);
    }

    /// @notice Preview the amount of assets that would be withdrawn for a given amount of shares
    /// @param _assetAmount The amount of assets for which to preview the withdrawal
    /// @return The previewed withdrawable amount
    function _previewWithdraw(uint256 _assetAmount) internal override view returns (uint256) {
        /// @dev using convertToShares + previewRedeem instead of previewWithdraw to round down
        uint256 shares = EXTERNAL_VAULT.convertToShares(_assetAmount);
        return EXTERNAL_VAULT.previewRedeem(shares);
    }

    /// @notice Prepares the contract for migration by redeeming all shares from the external vault
    function _beforeMigration() internal override {
        EXTERNAL_VAULT.redeem(EXTERNAL_VAULT.balanceOf(address(this)), address(this), address(this));
    }

    /// @notice Deposits assets into the external vault
    /// @dev Can only be called by authorized users
    /// @param assetsToDeposit The amount of assets to deposit
    /// @param minShares The minimum acceptable shares to receive for the deposited assets
    function depositToExternalVault(uint256 assetsToDeposit, uint256 minShares) external requiresAuth {
        ASSET_TOKEN.safeIncreaseAllowance(address(EXTERNAL_VAULT), assetsToDeposit);
        uint256 shares = EXTERNAL_VAULT.deposit(assetsToDeposit, address(this));
        if (shares < minShares) {
            revert TooFewSharesReceived(minShares, shares);
        }
    }

    /// @notice Redeems shares from the external vault
    /// @dev Can only be called by authorized users
    /// @param sharesToRedeem The number of shares to redeem
    /// @param minAssets The minimum acceptable assets to receive for the redeemed shares
    function redeemFromExternalVault(uint256 sharesToRedeem, uint256 minAssets) external requiresAuth {
        uint256 assets = EXTERNAL_VAULT.redeem(sharesToRedeem, address(this), address(this));
        if (assets < minAssets) {
            revert TooFewAssetsReceived(minAssets, assets);
        }
    }
}
