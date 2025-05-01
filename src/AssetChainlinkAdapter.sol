// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {AggregatorV3Interface} from "./Dependencies/AggregatorV3Interface.sol";

/**
 * @title AssetChainlinkAdapter contract
 * @notice Helps convert asset to BTC prices by combining two different oracle readings.
 */
contract AssetChainlinkAdapter is AggregatorV3Interface {
    uint8 public constant override decimals = 18;
    uint256 public constant override version = 1;

    /**
     * @notice Maximum number of resulting and feed decimals
     */
    uint8 public constant MAX_DECIMALS = 18;

    int256 internal constant ADAPTER_PRECISION = int256(10 ** decimals);

    /**
     * @notice Price feed for (ASSET / USD) pair (asset = tBTC, cbBTC etc.)
     */
    AggregatorV3Interface public immutable ASSET_USD_CL_FEED;

    /**
     * @notice Price feed for (BTC / USD) pair
     */
    AggregatorV3Interface public immutable BTC_USD_CL_FEED;

    /// @notice max freshness for the ASSET/USD feed
    uint256 public immutable ASSET_FEED_FRESHNESS;

    /// @notice max freshness for the BTC/USD feed
    uint256 public immutable BTC_FEED_FRESHNESS;

    /// @notice Specifies if the price of this adapter should be inverted (BTC/ASSET instead of ASSET/BTC)
    bool public immutable INVERTED;

    int256 internal immutable ASSET_USD_PRECISION;
    int256 internal immutable BTC_USD_PRECISION;

    error WrongDecimals();

    error OracleRound();
    error OracleAnswer();
    error OracleStale();

    /**
     * @notice Contract constructor
     * @param _assetUsdClFeed AggregatorV3Interface contract feed for Asset -> USD
     * @param _btcUsdClFeed AggregatorV3Interface contract feed for BTC -> USD
     * @param _inverted indicates wether the price conversion is inverted, meaning is btc/Asset
     */
    constructor(
        AggregatorV3Interface _assetUsdClFeed,
        uint256 _maxAssetFreshness,
        AggregatorV3Interface _btcUsdClFeed, 
        uint256 _maxBtcFreshness,
        bool _inverted
    ) {
        ASSET_USD_CL_FEED = AggregatorV3Interface(_assetUsdClFeed);
        ASSET_FEED_FRESHNESS = _maxAssetFreshness;
        BTC_USD_CL_FEED = AggregatorV3Interface(_btcUsdClFeed);
        BTC_FEED_FRESHNESS = _maxBtcFreshness;
        INVERTED = _inverted;

        require(ASSET_USD_CL_FEED.decimals() <= MAX_DECIMALS, WrongDecimals());
        require(BTC_USD_CL_FEED.decimals() <= MAX_DECIMALS, WrongDecimals());

        ASSET_USD_PRECISION = int256(10 ** ASSET_USD_CL_FEED.decimals());
        BTC_USD_PRECISION = int256(10 ** BTC_USD_CL_FEED.decimals());
    }

    function description() external view returns (string memory) {
        if (INVERTED) {
            return "BTC/ASSET Chainlink Adapter";
        } else {
            return "ASSET/BTC Chainlink Adapter";
        }
    }
    /** @notice returns the smallest uint256 out of the 2 parameters
    * @param _a first number to compare
    * @param _b second number to compare
    */
    function _min(uint256 _a, uint256 _b) private pure returns (uint256) {
        return _a < _b ? _a : _b;
    }

    /// @dev Uses the prices from the asset feed and the BTC feed to compute ASSET->BTC
    function _convertAnswer(int256 btcUsdPrice, int256 assetUsdPrice) private view returns (int256) {
        if (INVERTED) {
            return
                (btcUsdPrice * ASSET_USD_PRECISION * ADAPTER_PRECISION) / 
                (BTC_USD_PRECISION * assetUsdPrice);
        } else {
            return
                (assetUsdPrice * BTC_USD_PRECISION * ADAPTER_PRECISION) / 
                (ASSET_USD_PRECISION * btcUsdPrice);
        }
    }

    function _latestRoundData(
        AggregatorV3Interface _feed,
        uint256 maxFreshness
    ) private view returns (int256 answer, uint256 updatedAt) {
        uint80 feedRoundId;
        (feedRoundId, answer, , updatedAt, ) = _feed.latestRoundData();
        require(feedRoundId > 0, OracleRound());
        require(answer > 0, OracleAnswer());
        require((block.timestamp - updatedAt) <= maxFreshness, OracleStale());
    }

    /// @dev Needed because we inherit from AggregatorV3Interface
    function getRoundData(
        uint80 _roundId
    )
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){}

    /// @notice `roundId`, `startedAt` and `answeredInRound` are not used
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (int256 assetUsdPrice, uint256 assetUsdUpdatedAt) = _latestRoundData(ASSET_USD_CL_FEED, ASSET_FEED_FRESHNESS);
        (int256 btcUsdPrice, uint256 btcUsdUpdatedAt) = _latestRoundData(BTC_USD_CL_FEED, BTC_FEED_FRESHNESS);

        updatedAt = _min(assetUsdUpdatedAt, btcUsdUpdatedAt);
        answer = _convertAnswer(btcUsdPrice, assetUsdPrice);
    }
}