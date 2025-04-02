// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {AssetChainlinkAdapter, AggregatorV3Interface} from "../src/AssetChainlinkAdapter.sol";
import {MockAssetOracle} from "./mocks/MockAssetOracle.sol";


contract AssetChainlinkAdapterTests is Test {

    MockAssetOracle internal usdAssetAggregator;
    MockAssetOracle internal btcUsdAggregator;
    AssetChainlinkAdapter internal assetChainlinkAdapter;

    function setUp() public {
        usdAssetAggregator = new MockAssetOracle(8);
        btcUsdAggregator = new MockAssetOracle(8);
        assetChainlinkAdapter = new AssetChainlinkAdapter(
            usdAssetAggregator, 
            1 days + 2 hours,
            btcUsdAggregator,
            2 hours, 
            false
        );
    }

    function testGetLatestRound() public {
        usdAssetAggregator.setLatestRoundId(110680464442257320247);
        usdAssetAggregator.setPrevRoundId(110680464442257320246);
        usdAssetAggregator.setPrice(3983705362408);
        usdAssetAggregator.setUpdateTime(block.timestamp);

        btcUsdAggregator.setLatestRoundId(110680464442257320665);
        btcUsdAggregator.setPrevRoundId(110680464442257320664);
        btcUsdAggregator.setPrice(221026137517);
        btcUsdAggregator.setUpdateTime(block.timestamp);

        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,
        ) = assetChainlinkAdapter.latestRoundData();

        assertEq(answer, 18023684470808785517);
        assertEq(updatedAt, block.timestamp);
    }
    
    //test that the conversion is correct using known numbers
    function testConversionWorks() public {
        // Asset > BTC
        // ASSET
        usdAssetAggregator.setLatestRoundId(1);
        usdAssetAggregator.setPrice(2);
        // BTC
        btcUsdAggregator.setLatestRoundId(1);
        btcUsdAggregator.setPrice(1);// half the price

        (
            ,
            int256 answer,,,
        ) = assetChainlinkAdapter.latestRoundData();

        assertEq(answer, 2000000000000000000);// (ASSET/BTC) * ADAPTER_PRECISION

        // ASSET < BTC
        // ASSET
        usdAssetAggregator.setLatestRoundId(1);
        usdAssetAggregator.setPrice(1);
        
        // BTC
        btcUsdAggregator.setLatestRoundId(1);        
        btcUsdAggregator.setPrice(2);// double the price
        
        (
            ,
            answer,,,
        ) = assetChainlinkAdapter.latestRoundData();

        assertEq(answer, 500000000000000000);// (ASSET/BTC) * ADAPTER_PRECISION
    }

    function testConversionWorksInverted() public {
        assetChainlinkAdapter = new AssetChainlinkAdapter(
            usdAssetAggregator, 
            1 days + 2 hours,
            btcUsdAggregator,
            2 hours, 
            true
        );

        // Asset > BTC
        // ASSET
        usdAssetAggregator.setLatestRoundId(1);
        usdAssetAggregator.setPrice(2);
        // BTC
        btcUsdAggregator.setLatestRoundId(1);
        btcUsdAggregator.setPrice(1);// half the price

        (
            ,
            int256 answer,,,
        ) = assetChainlinkAdapter.latestRoundData();

        assertEq(answer, 500000000000000000);// (ASSET/BTC) * ADAPTER_PRECISION

        // ASSET < BTC
        // ASSET
        usdAssetAggregator.setLatestRoundId(1);
        usdAssetAggregator.setPrice(1);
        
        // BTC
        btcUsdAggregator.setLatestRoundId(1);        
        btcUsdAggregator.setPrice(2);// double the price
        
        (
            ,
            answer,,,
        ) = assetChainlinkAdapter.latestRoundData();

        assertEq(answer, 2000000000000000000);// (ASSET/BTC) * ADAPTER_PRECISION
    }

    function testWithRealData() public {
        string memory rpcUrl = vm.envString("RPC_URL");
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);
        // test that reading the prices work by rolling to a block in mainnet that actually 
        // we know the prices and confirm the conversion works
        address assetUsdFeed = 0x8350b7De6a6a2C1368E7D4Bd968190e13E354297;
        address btcUsdFeed = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
        
        AssetChainlinkAdapter adapter = new AssetChainlinkAdapter(
            AggregatorV3Interface(assetUsdFeed), 
            1 days + 2 hours,
            AggregatorV3Interface(btcUsdFeed), 
            2 hours,
            false
        );
        
        (uint80 roundID, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = adapter.latestRoundData();
        emit log_named_int("Converted Asset to BTC price", answer);
        assertTrue(answer > 0, "Conversion should yield a positive number");
    }
}
