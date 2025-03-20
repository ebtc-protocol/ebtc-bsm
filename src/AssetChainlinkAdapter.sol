// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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

    /// @notice Specifies if the price of this adapter should be inverted (BTC/ASSET instead of ASSET/BTC)
    bool public immutable INVERTED;

    int256 internal immutable ASSET_USD_PRECISION;
    int256 internal immutable BTC_USD_PRECISION;

    /**
     * @notice Contract constructor
     * @param _assetUsdClFeed AggregatorV3Interface contract feed for Asset -> USD
     * @param _btcUsdClFeed AggregatorV3Interface contract feed for BTC -> USD
     * @param _inverted indicates wether the price conversion is btc/Asset or Asset/BTC
     */
    constructor(AggregatorV3Interface _assetUsdClFeed, AggregatorV3Interface _btcUsdClFeed, bool _inverted) {
        ASSET_USD_CL_FEED = AggregatorV3Interface(_assetUsdClFeed);
        BTC_USD_CL_FEED = AggregatorV3Interface(_btcUsdClFeed);
        INVERTED = _inverted;

        require(ASSET_USD_CL_FEED.decimals() <= MAX_DECIMALS);
        require(BTC_USD_CL_FEED.decimals() <= MAX_DECIMALS);

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
        AggregatorV3Interface _feed
    ) private view returns (int256 answer, uint256 updatedAt) {
        uint80 feedRoundId;
        (feedRoundId, answer, , updatedAt, ) = _feed.latestRoundData();
        require(feedRoundId > 0);
        require(answer > 0);
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

    // latestRoundData should raise "No data present"
    // if this do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values. //TODO?
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
        (int256 assetUsdPrice, uint256 assetUsdUpdatedAt) = _latestRoundData(ASSET_USD_CL_FEED);
        (int256 btcUsdPrice, uint256 btcUsdUpdatedAt) = _latestRoundData(BTC_USD_CL_FEED);

        updatedAt = _min(assetUsdUpdatedAt, btcUsdUpdatedAt);
        answer = _convertAnswer(btcUsdPrice, assetUsdPrice);
    }
}