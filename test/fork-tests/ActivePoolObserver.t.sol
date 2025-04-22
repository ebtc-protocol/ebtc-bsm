// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ActivePoolObserver} from "../src/ActivePoolObserver.sol"; 
import {ITwapWeightedObserver} from "../src/Dependencies/ITwapWeightedObserver.sol"; 

contract ActivePoolObserverTest is Test {
    ActivePoolObserver public activePoolObserver;

    ITwapWeightedObserver public activePool = ITwapWeightedObserver(0x6dBDB6D420c110290431E863A1A978AE53F69ebC);

    function setUp() public {
        activePoolObserver = new ActivePoolObserver(ITwapWeightedObserver(0x6dBDB6D420c110290431E863A1A978AE53F69ebC));//Use actual address TODO
    }

    // forge test --match-test test_check_math --rpc-url https://eth-mainnet.g.alchemy.com/v2/mUhSl9trIQUL4usawoforWzPFxtruAm7 -vvv
    function test_check_math() public {
        console2.log("Observer");
        console2.log(activePoolObserver.observe());

        console2.log("activePool.PERIOD()", activePool.PERIOD());

        /// OBSERVER
        uint256 obsCount = 100;

        uint256[] memory observations_view = new uint256[](obsCount);
        uint256[] memory observations_write = new uint256[](obsCount);

        uint256 daysIncrease = 7 days;

        uint256 snap = vm.snapshot();
        uint256 max = daysIncrease * obsCount;
        uint256 acc;
        uint i;
        while(acc < max) {
            acc += daysIncrease;
            vm.warp(block.timestamp + daysIncrease);
            console2.log("");
            console2.log("Week", acc / daysIncrease);
            console2.log("From AP");
            ITwapWeightedObserver.PackedData memory data = activePool.getData();
            console2.log("latestAcc", activePool.getLatestAccumulator());
            console2.log("data.observerCumuVal", data.observerCumuVal);
            console2.log("data.accumulatorc", data.accumulator);
            console2.log("valueToTrack", activePool.valueToTrack());
            console2.log("block.timestamp", block.timestamp);
            console2.log("data.lastAccrued", data.lastAccrued);
            console2.log("data.lastObserved", data.lastObserved);
            console2.log(activePoolObserver.observe());
            observations_view[i++] = activePoolObserver.observe();
        }
        console2.log("TARGET"); /// Get the result above, that one will match the unaccrued TWAP, meaning the issue is in the math, not the observer
        console2.log("");
        console2.log("");

        vm.revertTo(snap);

        /// WEEK BY WEEK ACCRUAL

        acc = 0;
        console2.log("");
        console2.log("AP");
        console2.log(activePool.observe());
        i = 0;
        while(acc < max) {
            acc += daysIncrease;
            vm.warp(block.timestamp + daysIncrease);
            console2.log("");
            console2.log("Week", acc / daysIncrease);
            console2.log("From AP");
            ITwapWeightedObserver.PackedData memory data = activePool.getData();
            console2.log("latestAcc", activePool.getLatestAccumulator());
            console2.log("data.observerCumuVal", data.observerCumuVal);
            console2.log("data.accumulatorc", data.accumulator);
            console2.log("valueToTrack", activePool.valueToTrack());
            console2.log("block.timestamp", block.timestamp);
            console2.log("data.lastAccrued", data.lastAccrued);
            console2.log("data.lastObserved", data.lastObserved);
            console2.log(activePool.observe());
            observations_write[i++] = activePool.observe();
        }

        vm.revertTo(snap);

        /// LIVE

        // Skip the entire period then do the check
        vm.warp(block.timestamp + max);
        console2.log("");
        console2.log("Week", acc / daysIncrease);
        console2.log("From AP");
        ITwapWeightedObserver.PackedData memory data = activePool.getData();
        console2.log("latestAcc", activePool.getLatestAccumulator());
        console2.log("data.observerCumuVal", data.observerCumuVal);
        console2.log("data.accumulatorc", data.accumulator);
        console2.log("valueToTrack", activePool.valueToTrack());
        console2.log("block.timestamp", block.timestamp);
        console2.log("data.lastAccrued", data.lastAccrued);
        console2.log("data.lastObserved", data.lastObserved);
        console2.log(activePool.observe());


        // Diff the results
        for(uint256 l; l < obsCount; l++) {
            console2.log("Delta l", l);
            if(observations_write[l] > observations_view[l]) {
                console2.log("Delta value",  observations_write[l] - observations_view[l]);
            } else {
                console2.log("Delta value",  observations_view[l] - observations_write[l]);
            }
            
        }

        // Absolute impact
        console2.log("Max Impact BPS", observations_write[0] * 10_000 / observations_view[0]);
        console2.log("Max Impact BPS", observations_write[1] * 10_000 / observations_view[1]);
        console2.log("Max Impact BPS", observations_write[2] * 10_000 / observations_view[2]);
    }
}
