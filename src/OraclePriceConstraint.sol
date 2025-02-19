// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {AuthNoOwner} from "./Dependencies/AuthNoOwner.sol";
import {IMintingConstraint} from "./Dependencies/IMintingConstraint.sol";
import {AggregatorV3Interface} from "./Dependencies/AggregatorV3Interface.sol";

/// @title Oracle Price Constraint for Minting
/// @notice This contract uses price feed from an oracle to set constraints on minting based on the asset's current market price.
/// @dev Implements IMintingConstraint to provide minting restrictions based on real-time asset price information provided by Chainlink oracles.
contract OraclePriceConstraint is IMintingConstraint, AuthNoOwner {
    /// @notice Basis points constant for price calculations
    uint256 public constant BPS = 10000;

    /// @notice Asset feed is denominated in BTC (i.e. tBTC/BTC)
    AggregatorV3Interface public immutable ASSET_FEED;

    /// @notice Precision of the asset price from the feed
    uint256 public immutable ASSET_FEED_PRECISION;

    /// @notice Minimum price, in basis points, below which minting is not allowed
    uint256 public minPriceBPS;

    /// @notice Maximum allowable age of the latest oracle price
    uint256 public oracleFreshnessSeconds;

    /// @notice Event emitted when the minimum price is updated
    event MinPriceUpdated(uint256 oldMinPrice, uint256 newMinPrice);

    /// @notice Event emitted when the oracle freshness requirement is updated
    event OracleFreshnessUpdated(
        uint256 oldOracleFreshness,
        uint256 newOracleFreshness
    );

    /// @notice Error thrown when the oracle price is invalid (non-positive)
    error BadOraclePrice(int256 price);

    /// @notice Error thrown when the latest oracle price is too old
    error StaleOraclePrice(uint256 updatedAt);

    /// @notice Error thrown when the asset price is below the minimum required for minting
    error BelowMinPrice(uint256 assetPrice, uint256 minPrice);

    /// @notice Contract constructor
    /// @param _assetFeed Address of the oracle price feed
    /// @param _governance Address of the governance authority
    constructor(address _assetFeed, address _governance) {
        ASSET_FEED = AggregatorV3Interface(_assetFeed);
        ASSET_FEED_PRECISION = 10 ** ASSET_FEED.decimals();
        _initializeAuthority(_governance);
        minPriceBPS = BPS;  // Default to 100%
        oracleFreshnessSeconds = 1 days;  // Default to 1 day
    }

    /// @notice Retrieves the latest price of the asset from the oracle
    /// @return The latest asset price normalized to 1e18 precision
    function _getAssetPrice() private view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = ASSET_FEED.latestRoundData();

        if (answer <= 0) revert BadOraclePrice(answer);
        if ((block.timestamp - updatedAt) > oracleFreshnessSeconds) {
            revert StaleOraclePrice(updatedAt);
        }

        return (uint256(answer) * 1e18) / ASSET_FEED_PRECISION;
    }

    /// @notice Determines if minting is allowed based on the current asset price
    /// @param _amount The amount of tokens requested to mint (unused in this contract)
    /// @param _minter The address requesting to mint (unused in this contract)
    /// @return bool True if minting is allowed, false otherwise
    /// @return bytes Encoded error data if minting is not allowed
    function canMint(
        uint256 _amount,
        address _minter
    ) external view returns (bool, bytes memory) {
        uint256 assetPrice = _getAssetPrice();
        /// @dev peg price is 1e18
        uint256 minAcceptablePrice = (1e18 * minPriceBPS) / BPS;

        if (minAcceptablePrice <= assetPrice) {
            return (true, "");
        } else {
            return (
                false,
                abi.encodeWithSelector(
                    BelowMinPrice.selector,
                    assetPrice,
                    minAcceptablePrice
                )
            );
        }
    }

    /// @notice Updates the minimum price threshold for minting
    /// @dev Can only be called by authorized users
    /// @param _minPriceBPS The new minimum price, in basis points
    function setMinPrice(uint256 _minPriceBPS) external requiresAuth {
        require(_minPriceBPS <= BPS);
        emit MinPriceUpdated(minPriceBPS, _minPriceBPS);
        minPriceBPS = _minPriceBPS;
    }

    /// @notice Updates the maximum age for acceptable oracle data
    /// @dev Can only be called by authorized users
    /// @param _oracleFreshnessSeconds The new maximum age in seconds
    function setOracleFreshness(
        uint256 _oracleFreshnessSeconds
    ) external requiresAuth {
        emit OracleFreshnessUpdated(
            oracleFreshnessSeconds,
            _oracleFreshnessSeconds
        );
        oracleFreshnessSeconds = _oracleFreshnessSeconds;
    }
}
