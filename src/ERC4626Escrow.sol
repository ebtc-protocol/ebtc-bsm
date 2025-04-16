// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

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
    uint256 public constant BPS = 10_000;

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

    /// @notice make sure we are not trying to redeem more shares than we have
    function _clampShares(uint256 _shares) internal view returns (uint256) {
        uint256 totalShares = EXTERNAL_VAULT.balanceOf(address(this));
        if (_shares > totalShares) {
            return totalShares;
        }
        return _shares;
    }

    /// @notice Ensures sufficient liquidity is available by redeeming assets from the external vault if necessary
    /// @param _amountRequired The amount of assets required
    /// @return _amountRedeemed The actual amount of assets redeemed
    function _ensureLiquidity(uint256 _amountRequired) private returns (uint256 _amountRedeemed) {
        /// @dev super._totalBalance() returns asset balance for this contract
        uint256 liquidBalance = super._totalBalance();
        
        if (_amountRequired > liquidBalance) {
            uint256 deficit;
            unchecked {
                deficit = _amountRequired - liquidBalance;
            }
            // using convertToShares here because it rounds down
            // this prevents the vault from taking on losses
            /// @notice We assume convertToShares always returns less shares than previewWithdraw
            /// @notice This may not be the case for Euler earn
            uint256 shares = _clampShares(EXTERNAL_VAULT.convertToShares(deficit));
            uint256 redeemed;
            /// @dev avoid redeeming 0 shares
            if (shares > 0) {
                uint256 balanceBefore = ASSET_TOKEN.balanceOf(address(this));
                EXTERNAL_VAULT.redeem(shares, address(this), address(this));
                uint256 balanceAfter = ASSET_TOKEN.balanceOf(address(this));
                redeemed = balanceAfter - balanceBefore;
            }
            // amountRedeemed can be less than deficit because of rounding
            _amountRedeemed = liquidBalance + redeemed;
            
            /// @audit Some vaults (most OOS) do not accrue their assets in `convertToShares`
            /// This can cause `redeem` to withdraw more than requested
            /// To prevent abuse, we cap at deficit
            if(redeemed > deficit) {
                _amountRedeemed = liquidBalance + deficit; // Cap for edge case
            }
        } else {
            // We have liquid amount so we return it
            _amountRedeemed = _amountRequired;
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
    function _withdrawProfit(uint256 _profitAmount) internal override returns (uint256) {
        uint256 redeemedAmount = _ensureLiquidity(_profitAmount);
        return super._withdrawProfit(redeemedAmount);
    }

    /// @notice Preview the amount of assets that would be withdrawn for a given amount of shares
    /// @param _assetAmount The amount of assets for which to preview the withdrawal
    /// @return The previewed withdrawable amount
    function _previewWithdraw(uint256 _assetAmount) internal override view returns (uint256) {
        uint256 liquidBalance = super._totalBalance();        
       
        if (_assetAmount > liquidBalance) {
            uint256 deficit;
            unchecked {
                deficit = _assetAmount - liquidBalance;
            }

            /// @dev using convertToShares + previewRedeem instead of previewWithdraw to round down
            uint256 shares = _clampShares(EXTERNAL_VAULT.convertToShares(deficit));

            /// Cap for edge case when `previewRedeem` returns more assets than `convertToShares`
            uint256 redeemed;
            if(shares > 0) {
                redeemed = EXTERNAL_VAULT.previewRedeem(shares);
                if(redeemed > deficit) {
                    redeemed = deficit; // Cap for edge case
                }
            }
            return liquidBalance + redeemed;
        } else {
            return _assetAmount;
        }
    }

    /// @notice Prepares the contract for migration by redeeming all shares from the external vault
    /// @notice We expect to redeem here only if the escrow balance is low. For large escrow balances,
    /// we will call `redeemFromExternalVault` before a migration to have proper slippage checks.
    function _beforeMigration() internal override {
        uint256 shares = EXTERNAL_VAULT.balanceOf(address(this));
        if (shares > 0) {
            EXTERNAL_VAULT.redeem(shares, address(this), address(this));
        }
    }

    function _claimTokens(address token, uint256 amount) internal override {
        require(token != address(EXTERNAL_VAULT), InvalidToken());
        super._claimTokens(token, amount);
    }

    /// @notice Deposits assets into the external vault
    /// @dev Can only be called by authorized users
    /// @dev Can cause losses if the admin is not careful
    /// @dev Assumes: Slippage check is safe
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
