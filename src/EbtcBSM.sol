// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {AuthNoOwner} from "./Dependencies/AuthNoOwner.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

    uint256 internal immutable ASSET_TOKEN_PRECISION;

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

    /// @notice Constraint for buying asset tokens
    IMintingConstraint public buyAssetConstraint;

    /// @notice Error for when there are insufficient asset tokens available
    error InsufficientAssetTokens(uint256 required, uint256 available);

    /// @notice Error for when the actual output amount is below the expected amount
    error BelowExpectedMinOutAmount(uint256 expected, uint256 actual);

    /// @notice Error for when the amount passed into sellAsset or buyAsset is zero
    error ZeroAmount();

    /// @notice Error for when the recipient address is the zero address
    error InvalidRecipientAddress();

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
        address _buyAssetConstraint,
        address _ebtcToken,
        address _governance
    ) {
        require(_assetToken != address(0));
        require(_oraclePriceConstraint != address(0));
        require(_rateLimitingConstraint != address(0));
        require(_buyAssetConstraint != address(0));
        require(_ebtcToken != address(0));
        require(_governance != address(0));

        ASSET_TOKEN = IERC20(_assetToken);
        ASSET_TOKEN_PRECISION = 10 ** ERC20(_assetToken).decimals();
        require(ASSET_TOKEN_PRECISION <= 1e18);
        oraclePriceConstraint = IMintingConstraint(_oraclePriceConstraint);
        rateLimitingConstraint = IMintingConstraint(_rateLimitingConstraint);
        buyAssetConstraint = IMintingConstraint(_buyAssetConstraint);
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

    /** @notice Calculates the fee for buying asset tokens
    * @param _amount Amount of asset tokens to buy
    * @return Fee amount
    */
    function _feeToBuy(uint256 _amount) private view returns (uint256) {
        return (_amount * feeToBuyBPS) / BPS;
    }

    /** @notice Calculates the fee for selling asset tokens
    * @param _amount Amount of asset tokens to sell
    * @return Fee amount
    */
    function _feeToSell(uint256 _amount) private view returns (uint256) {
        uint256 fee = feeToSellBPS;
        return (_amount * fee) / (fee + BPS);
    }

    function _toAssetPrecision(uint256 _amount) private view returns (uint256)  {
        return _amount * ASSET_TOKEN_PRECISION / 1e18;
    }

    function _toEbtcPrecision(uint256 _amount) private view returns (uint256) {
        return _amount * 1e18 / ASSET_TOKEN_PRECISION;
    }

    function _previewSellAsset(
        uint256 _assetAmountIn,
        uint256 _feeAmount
    ) private view returns (uint256 _ebtcAmountOut) {
        _ebtcAmountOut = _toEbtcPrecision(_assetAmountIn - _feeAmount);
        _checkMintingConstraints(_ebtcAmountOut);
    }

    function _previewBuyAsset(
        uint256 _ebtcAmountIn,
        uint256 _feeAmount
    ) private view returns (uint256 _assetAmountOut) {
        uint256 ebtcAmountInAssetPrecision = _toAssetPrecision(_ebtcAmountIn);
        uint256 feeAmountInAssetPrecision = _toAssetPrecision(_feeAmount);
        _checkBuyAssetConstraints(ebtcAmountInAssetPrecision);
        _assetAmountOut = escrow.previewWithdraw(ebtcAmountInAssetPrecision) - feeAmountInAssetPrecision;
    }

    /** @notice This internal function verifies that the escrow has sufficient assets deposited to cover an amount to buy.
    * @param amountToBuy The amount of assets that is intended to be bought (in asset precision)
    */
    function _checkBuyAssetConstraints(uint256 amountToBuy) private view {
        // ebtc to asset price is treated as 1 for buyAsset
        /// @dev totalAssetsDeposited is in asset precision
        uint256 totalAssetsDeposited = escrow.totalAssetsDeposited();
        if (amountToBuy > totalAssetsDeposited) {
            revert InsufficientAssetTokens(amountToBuy, totalAssetsDeposited);
        }

        bool success;
        bytes memory errData;

        (success, errData) = buyAssetConstraint.canMint(amountToBuy, address(this));
        if (!success) {
            revert IMintingConstraint.MintingConstraintCheckFailed(
                address(buyAssetConstraint),
                amountToBuy,
                address(this),
                errData
            );
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

    /// @notice Internal sellAsset function with an expected fee amount
    function _sellAsset(
        uint256 _assetAmountIn, // asset precision
        address _recipient,
        uint256 _feeAmount,   // asset precision
        uint256 _minOutAmount // ebtc precision
    ) internal returns (uint256 _ebtcAmountOut) { // ebtc precision
        if (_assetAmountIn == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert InvalidRecipientAddress();
        
        uint256 assetAmountInNoFee = _assetAmountIn - _feeAmount;

        // Convert _assetAmountIn to ebtc precision (1e18)
        _ebtcAmountOut = _toEbtcPrecision(assetAmountInNoFee);

        _checkMintingConstraints(_ebtcAmountOut);

        // INVARIANT: _assetAmountIn >= _ebtcAmountOut
        ASSET_TOKEN.safeTransferFrom(
            msg.sender,
            address(escrow),
            _assetAmountIn // asset precision
        );
        // assetAmountInNoFee = _assetAmountIn - _feeAmount (asset precision)
        escrow.onDeposit(assetAmountInNoFee);

        // slippage check
        if (_ebtcAmountOut < _minOutAmount) {
            revert BelowExpectedMinOutAmount(_minOutAmount, _ebtcAmountOut);
        }

        totalMinted += _ebtcAmountOut;

        EBTC_TOKEN.mint(_recipient, _ebtcAmountOut);

        emit AssetSold(_assetAmountIn, _ebtcAmountOut, _feeAmount);
    }

    /// @notice Internal buyAsset function with an expected fee amount
    function _buyAsset(
        uint256 _ebtcAmountIn, // ebtc precision
        address _recipient,
        uint256 _feeAmount,    // ebtc precision
        uint256 _minOutAmount  // asset precision
    ) internal returns (uint256 _assetAmountOut) { // asset precision
        if (_ebtcAmountIn == 0) revert ZeroAmount();
        if (_recipient == address(0)) revert InvalidRecipientAddress();

        uint256 ebtcAmountInAssetPrecision = _toAssetPrecision(_ebtcAmountIn);
        
        if (ebtcAmountInAssetPrecision == 0) revert ZeroAmount();

        _checkBuyAssetConstraints(ebtcAmountInAssetPrecision);

        EBTC_TOKEN.burn(msg.sender, _ebtcAmountIn);

        totalMinted -= _ebtcAmountIn;

        uint256 redeemedAmount = escrow.onWithdraw(
            ebtcAmountInAssetPrecision
        );
        uint256 feeAmountInAssetPrecision = _toAssetPrecision(_feeAmount);

        _assetAmountOut = redeemedAmount - feeAmountInAssetPrecision; // asset precision

        // slippage check
        if (_assetAmountOut < _minOutAmount) {
            revert BelowExpectedMinOutAmount(_minOutAmount, _assetAmountOut);
        }

        if (_assetAmountOut > 0) {
            // INVARIANT: _assetAmountOut <= _ebtcAmountIn
            ASSET_TOKEN.safeTransferFrom(
                address(escrow),
                _recipient,
                _assetAmountOut
            );
        }

        emit AssetBought(_ebtcAmountIn, _assetAmountOut, _feeAmount);
    }

    /** 
     * @notice Calculates the amount of eBTC minted for a given amount of asset tokens accounting
     * for all minting constraints
     * @param _assetAmountIn the total amount intended to be deposited
     * @return _ebtcAmountOut the estimated eBTC to mint after fees
     */
    function previewSellAsset(
        uint256 _assetAmountIn
    ) external view returns (uint256 _ebtcAmountOut) {
        return _previewSellAsset(_assetAmountIn, _feeToSell(_assetAmountIn));
    }

    /** 
     * @notice Calculates the net asset amount that can be bought with a given amount of eBTC
     * @param _ebtcAmountIn the total amount intended to be deposited
     * @return _assetAmountOut the estimated asset to buy after fees
     */
    function previewBuyAsset(
        uint256 _ebtcAmountIn
    ) external view returns (uint256 _assetAmountOut) {
        return _previewBuyAsset(_ebtcAmountIn, _feeToBuy(_ebtcAmountIn));
    }

    /**
     * @notice Allows users to mint eBTC by depositing asset tokens
     * @param _assetAmountIn Amount of asset tokens to deposit
     * @param _recipient custom recipient for the minted eBTC
     * @param _minOutAmount minimum eBTC expected after slippage
     * @return _ebtcAmountOut Amount of eBTC tokens minted to the user
     */
    function sellAsset(
        uint256 _assetAmountIn,
        address _recipient,
        uint256 _minOutAmount
    ) external whenNotPaused returns (uint256 _ebtcAmountOut) {
        return
            _sellAsset(_assetAmountIn, _recipient, _feeToSell(_assetAmountIn), _minOutAmount);
    }

    /**
     * @notice Allows users to buy BSM owned asset tokens by burning their eBTC
     * @param _ebtcAmountIn Amount of eBTC tokens to burn
     * @param _recipient custom recipient for the asset
     * @param _minOutAmount minimum asset tokens expected after slippage
     * @return _assetAmountOut Amount of asset tokens sent to user
     */
    function buyAsset(
        uint256 _ebtcAmountIn,
        address _recipient,
        uint256 _minOutAmount
    ) external whenNotPaused returns (uint256 _assetAmountOut) {
        return _buyAsset(_ebtcAmountIn, _recipient, _feeToBuy(_ebtcAmountIn), _minOutAmount);
    }

    /**
     * @notice Allows authorized users to mint eBTC by depositing asset tokens without applying a fee
     * @dev can only be called by authorized users
     * @param _assetAmountIn Amount of asset tokens to deposit
     * @param _recipient custom recipient for the minted eBTC
     * @param _minOutAmount minimum eBTC expected after slippage
     * @return _ebtcAmountOut Amount of eBTC tokens minted to the user
     */
    function sellAssetNoFee(
        uint256 _assetAmountIn,
        address _recipient,
        uint256 _minOutAmount
    ) external whenNotPaused requiresAuth returns (uint256 _ebtcAmountOut) {
        return _sellAsset(_assetAmountIn, _recipient, 0, _minOutAmount);
    }

    /**
     * @notice Allows authorized users to buy BSM owned asset tokens by burning their eBTC
     * @dev Can only be called by authorized users
     * @param _ebtcAmountIn Amount of eBTC tokens to burn
     * @param _recipient custom recipient for the asset
     * @param _minOutAmount minimum asset tokens expected after slippage
     * @return _assetAmountOut Amount of asset tokens sent to user
     */
    function buyAssetNoFee(
        uint256 _ebtcAmountIn,
        address _recipient,
        uint256 _minOutAmount
    ) external whenNotPaused requiresAuth returns (uint256 _assetAmountOut) {
        return _buyAsset(_ebtcAmountIn, _recipient, 0, _minOutAmount);
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

    /** @notice Updates the buy asset constraint address
    * @dev Can only be called by authorized users
    * @param _newBuyAssetConstraint New address for the buy asset constraint
    */
    function setBuyAssetConstraint(address _newBuyAssetConstraint) external requiresAuth {
        require(_newBuyAssetConstraint != address(0));
        emit IMintingConstraint.MintingConstraintUpdated(address(buyAssetConstraint), _newBuyAssetConstraint);
        buyAssetConstraint = IMintingConstraint(_newBuyAssetConstraint);
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

