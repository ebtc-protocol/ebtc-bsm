// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {AuthNoOwner} from "./Dependencies/AuthNoOwner.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEbtcToken} from "./Dependencies/IEbtcToken.sol";
import {IEbtcBSM} from "./Dependencies/IEbtcBSM.sol";
import {IMintingConstraint} from "./Dependencies/IMintingConstraint.sol";
import {IEscrow} from "./Dependencies/IEscrow.sol";

/**
* @title eBTC Stability Module (BSM) Contract
* @notice Facilitates bi-directional exchange between eBTC and other BTC-denominated assets with no slippage.
* @dev This contract handles the core business logic for asset token operations including minting and redeeming eBTC.
*/
contract EbtcBSM is IEbtcBSM, Pausable, Initializable, AuthNoOwner {
    using SafeERC20 for IERC20;

    /// @notice Basis points constant for percentage calculations
    uint256 public constant BPS = 10000;

    /// @notice Maximum allowable fees in basis points
    uint256 public constant MAX_FEE = 2000;

    /// @notice Underlying asset token for eBTC
    IERC20 public immutable ASSET_TOKEN;

    /// @notice eBTC token contract
    IEbtcToken public immutable EBTC_TOKEN;

    /// @notice Fee for selling assets into eBTC (in basis points)
    uint256 public feeToSellBPS;

    /// @notice Fee for buying assets with eBTC (in basis points)
    uint256 public feeToBuyBPS;

    /// @notice Total amount of eBTC minted
    uint256 public totalMinted;

    /// @notice Escrow contract to hold asset tokens
    IEscrow public escrow;

    /// @notice Oracle-based price constraint for minting
    IMintingConstraint public oraclePriceConstraint;

    /// @notice Rate limiting constraint for minting
    IMintingConstraint public rateLimitingConstraint;

    /// @notice Error for when there are insufficient asset tokens available
    error InsufficientAssetTokens(uint256 required, uint256 available);

    /** @notice Constructs the EbtcBSM contract
    * @param _assetToken Address of the underlying asset token
    * @param _oraclePriceConstraint Address of the oracle price constraint
    * @param _rateLimitingConstraint Address of the rate limiting constraint
    * @param _ebtcToken Address of the eBTC token
    * @param _governance Address of the governor
    */
    constructor(
        address _assetToken,
        address _oraclePriceConstraint,
        address _rateLimitingConstraint,
        address _ebtcToken,
        address _governance
    ) {
        require(_assetToken != address(0));
        require(_oraclePriceConstraint != address(0));
        require(_rateLimitingConstraint != address(0));
        require(_ebtcToken != address(0));
        require(_governance != address(0));

        ASSET_TOKEN = IERC20(_assetToken);
        oraclePriceConstraint = IMintingConstraint(_oraclePriceConstraint);
        rateLimitingConstraint = IMintingConstraint(_rateLimitingConstraint);
        EBTC_TOKEN = IEbtcToken(_ebtcToken);
        _initializeAuthority(_governance);
    }

    /** @notice This function will be invoked only once within the same transaction as the deployment of
    * this contract, thereby preventing any other user from executing this function.
    * @param _escrow Address of the escrow contract
    */
    function initialize(address _escrow) initializer external {
        require(_escrow != address(0));
        escrow = IEscrow(_escrow);
    }

    /** @notice Calculates the fee for buying eBTC
    * @param _amount Amount of eBTC to buy
    * @return Fee amount
    */
    function _feeToBuy(uint256 _amount) private view returns (uint256) {
        return (_amount * feeToBuyBPS) / BPS;
    }

    /** @notice Calculates the fee for selling eBTC
    * @param _amount Amount of eBTC to sell
    * @return Fee amount
    */
    function _feeToSell(uint256 _amount) private view returns (uint256) {
        uint256 fee = feeToSellBPS;
        return (_amount * fee) / (fee + BPS);
    }

    /** @notice Checks for fees and minting constrains to determine the eBTC amount out.
    * @param _assetAmountIn the total amount intended to be deposited
    * @param _feeAmount the fee to be paid
    * @return Returns the estimated eBTC to sell
    */
    function _previewSellAsset(
        uint256 _assetAmountIn,
        uint256 _feeAmount
    ) private view returns (uint256 _ebtcAmountOut) {
        _ebtcAmountOut = _assetAmountIn - _feeAmount;
        _checkMintingConstraints(_ebtcAmountOut);
    }

    /** @notice Calculates the net asset amount that can be bought with a given amount of eBTC
    * @param _ebtcAmountIn the total amount intended to be deposited
    * @param _feeAmount the fee to be paid
    * @return Returns the estimated asset to buy after fees
    */
    function _previewBuyAsset(
        uint256 _ebtcAmountIn,
        uint256 _feeAmount
    ) private view returns (uint256 _assetAmountOut) {
        _checkTotalAssetsDeposited(_ebtcAmountIn);
        _assetAmountOut = escrow.previewWithdraw(_ebtcAmountIn) - _feeAmount;
    }

    /** @notice This internal function verifies that the escrow has sufficient assets deposited to cover an amount to buy.
    * @param amountToBuy The amount of assets that is intended to be bought.
    */
    function _checkTotalAssetsDeposited(uint256 amountToBuy) private view {
        // ebtc to asset price is treated as 1 for buyAsset
        uint256 totalAssetsDeposited = escrow.totalAssetsDeposited();
        if (amountToBuy > totalAssetsDeposited) {
            revert InsufficientAssetTokens(amountToBuy, totalAssetsDeposited);
        }
    }
    
    /** @notice Internal function to handle the minting constraints checks
    * @param _amountToMint Amount to be minted
    */
    function _checkMintingConstraints(uint256 _amountToMint) private view {
        bool success;
        bytes memory errData;

        (success, errData) = oraclePriceConstraint.canMint(_amountToMint, address(this));
        if (!success) {
            revert IMintingConstraint.MintingConstraintCheckFailed(
                address(oraclePriceConstraint),
                _amountToMint,
                address(this),
                errData
            );
        }

        (success, errData) = rateLimitingConstraint.canMint(_amountToMint, address(this));
        if (!success) {
            revert IMintingConstraint.MintingConstraintCheckFailed(
                address(rateLimitingConstraint),
                _amountToMint,
                address(this),
                errData
            );
        }
    }

    /**
     * @notice Allows users to mint eBTC by depositing asset tokens
     * @param _assetAmountIn Amount of asset tokens to deposit
     * @param _recipient custom recipient for the minted eBTC
     * @return _ebtcAmountOut Amount of eBTC tokens minted to the user
     */
    function _sellAsset(
        uint256 _assetAmountIn,
        address _recipient,
        uint256 _feeAmount
    ) internal returns (uint256 _ebtcAmountOut) {
        _ebtcAmountOut = _assetAmountIn - _feeAmount;

        _checkMintingConstraints(_ebtcAmountOut);

        // INVARIANT: _assetAmountIn >= _ebtcAmountOut
        ASSET_TOKEN.safeTransferFrom(
            msg.sender,
            address(escrow),
            _assetAmountIn
        );
        escrow.onDeposit(_ebtcAmountOut); // ebtcMinted = _assetAmountIn - fee

        totalMinted += _ebtcAmountOut;

        EBTC_TOKEN.mint(_recipient, _ebtcAmountOut);

        emit AssetSold(_assetAmountIn, _ebtcAmountOut, _feeAmount);
    }

    /**
     * @notice Allows users to buy BSM owned asset tokens by burning their eBTC
     * @dev This function assumes the exchange rate between the asset token and eBTC is 1:1
     *
     * @param _ebtcAmountIn Amount of eBTC tokens to burn
     * @param _recipient custom recipient for the asset
     * @return _assetAmountOut Amount of asset tokens sent to user
     */
    function _buyAsset(
        uint256 _ebtcAmountIn,
        address _recipient,
        uint256 _feeAmount
    ) internal returns (uint256 _assetAmountOut) {
        _checkTotalAssetsDeposited(_ebtcAmountIn);

        EBTC_TOKEN.burn(msg.sender, _ebtcAmountIn);

        totalMinted -= _ebtcAmountIn;

        uint256 redeemedAmount = escrow.onWithdraw(
            _ebtcAmountIn
        );

        _assetAmountOut = redeemedAmount - _feeAmount;
        // INVARIANT: _assetAmountOut <= _ebtcAmountIn
        ASSET_TOKEN.safeTransferFrom(
            address(escrow),
            _recipient,
            _assetAmountOut
        );

        emit AssetBought(_ebtcAmountIn, _assetAmountOut, _feeAmount);
    }

    /// @dev Calls the internal function _previewSellAsset
    function previewSellAsset(
        uint256 _assetAmountIn
    ) external returns (uint256 _ebtcAmountOut) {
        return _previewSellAsset(_assetAmountIn, _feeToSell(_assetAmountIn));
    }

    /// @dev Calls the internal function _previewBuyAsset
    function previewBuyAsset(
        uint256 _ebtcAmountIn
    ) external returns (uint256 _assetAmountOut) {
        return _previewBuyAsset(_ebtcAmountIn, _feeToBuy(_ebtcAmountIn));
    }

    /// @dev Calls the internal function _sellAsset
    function sellAsset(
        uint256 _assetAmountIn,
        address _recipient
    ) external whenNotPaused returns (uint256 _ebtcAmountOut) {
        return
            _sellAsset(_assetAmountIn, _recipient, _feeToSell(_assetAmountIn));
    }

    /// @dev Calls the internal function _buyAsset
    function buyAsset(
        uint256 _ebtcAmountIn,
        address _recipient
    ) external whenNotPaused returns (uint256 _assetAmountOut) {
        return _buyAsset(_ebtcAmountIn, _recipient, _feeToBuy(_ebtcAmountIn));
    }

    /**
     * @notice Allows authorized users to mint eBTC by depositing asset tokens without applying a fee
     * @dev can only be called by authorized users
     * @param _assetAmountIn Amount of asset tokens to deposit
     * @param _recipient custom recipient for the minted eBTC
     * @return _ebtcAmountOut Amount of eBTC tokens minted to the user
     */
    function sellAssetNoFee(
        uint256 _assetAmountIn,
        address _recipient
    ) external whenNotPaused requiresAuth returns (uint256 _ebtcAmountOut) {
        return _sellAsset(_assetAmountIn, _recipient, 0);
    }

    /**
     * @notice Allows authorized users to buy BSM owned asset tokens by burning their eBTC
     * @dev Can only be called by authorized users
     * @param _ebtcAmountIn Amount of eBTC tokens to burn
     * @param _recipient custom recipient for the asset
     * @return _assetAmountOut Amount of asset tokens sent to user
     */
    function buyAssetNoFee(
        uint256 _ebtcAmountIn,
        address _recipient
    ) external whenNotPaused requiresAuth returns (uint256 _assetAmountOut) {
        return _buyAsset(_ebtcAmountIn, _recipient, 0);
    }

    /** @notice Sets the fee for selling eBTC
    * @dev Can only be called by authorized users
    * @param _feeToSellBPS Fee in basis points
    */
    function setFeeToSell(uint256 _feeToSellBPS) external requiresAuth {
        require(_feeToSellBPS <= MAX_FEE);
        emit FeeToSellUpdated(feeToSellBPS, _feeToSellBPS);
        feeToSellBPS = _feeToSellBPS;
    }

    /** @notice Sets the fee for buying eBTC
    * @dev Can only be called by authorized users
    * @param _feeToBuyBPS Fee in basis points
    */
    function setFeeToBuy(uint256 _feeToBuyBPS) external requiresAuth {
        require(_feeToBuyBPS <= MAX_FEE);
        emit FeeToBuyUpdated(feeToBuyBPS, _feeToBuyBPS);
        feeToBuyBPS = _feeToBuyBPS;
    }

    /** @notice Updates the rate limiting constraint address
    * @dev Can only be called by authorized users
    * @param _newRateLimitingConstraint New address for the rate limiting constraint
    */
    function setRateLimitingConstraint(address _newRateLimitingConstraint) external requiresAuth {
        require(_newRateLimitingConstraint != address(0), "Invalid address");
        emit IMintingConstraint.MintingConstraintUpdated(address(rateLimitingConstraint), _newRateLimitingConstraint);
        rateLimitingConstraint = IMintingConstraint(_newRateLimitingConstraint);
    }

    /** @notice Updates the oracle price constraint address
    * @dev Can only be called by authorized users
    * @param _newOraclePriceConstraint New address for the oracle price constraint
    */
    function setOraclePriceConstraint(address _newOraclePriceConstraint) external requiresAuth {
        require(_newOraclePriceConstraint != address(0));
        emit IMintingConstraint.MintingConstraintUpdated(address(oraclePriceConstraint), _newOraclePriceConstraint);
        oraclePriceConstraint = IMintingConstraint(_newOraclePriceConstraint);
    }

    /** @notice Updates the escrow address and initiates an escrow migration
    * @dev Can only be called by authorized users
    * @param _newEscrow New escrow address
    */
    function updateEscrow(address _newEscrow) external requiresAuth {
        require(_newEscrow != address(0));

        uint256 totalBalance = escrow.totalBalance();
        if (totalBalance > 0) {
            /// @dev cache deposit amount (will be set to 0 after migrateTo())
            uint256 totalAssetsDeposited = escrow.totalAssetsDeposited();

            /// @dev transfer liquidity to new vault
            escrow.onMigrateSource(_newEscrow);

            /// @dev set totalAssetsDeposited on the new vault (fee amount should be 0 here)
            IEscrow(_newEscrow).onMigrateTarget(totalAssetsDeposited);
        }

        emit EscrowUpdated(address(escrow), _newEscrow);
        escrow = IEscrow(_newEscrow);
    }

    /// @notice Pauses the contract operations
    /// @dev Can only be called by authorized users
    function pause() external requiresAuth {
        _pause();
    }

    /// @notice Unpauses the contract operations
    /// @dev Can only be called by authorized users
    function unpause() external requiresAuth {
        _unpause();
    }
}

