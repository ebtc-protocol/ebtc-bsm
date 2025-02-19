// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ITwapWeightedObserver} from "./Dependencies/ITwapWeightedObserver.sol";

/**
 * @title ActivePoolObserver
 * @notice Observes the average value of a pool using a TWAP (Time-Weighted Average Price) mechanism.
 * @dev This contract interacts with an immutable TWAP observer to calculate virtual average values 
 *      and virtually sync TWAP based on elapsed time, and weights the average based on time
 *      passed since the last observation.
 */
contract ActivePoolObserver {
    /// @notice set this to the ActivePool
    ITwapWeightedObserver public immutable OBSERVER;

    /**
     * @notice Contract constructor
     * @param _observer Address of the TWAP observer contract
     */
    constructor(ITwapWeightedObserver _observer) {
        OBSERVER = _observer;
    }

    /**
     * @notice Calculates the updated average value based on the latest accumulator and time elapsed.
     * @dev Utilizes the accumulator difference and the time passed to calculate the average.
     *      Uses the formula: (newAcc - acc0) / (now - t0).
     * @param data The packed data containing the last observed cumulative value and timestamp.
     * @return avgValue The updated average value.
     * @return latestAcc The latest accumulator value from the observer.
     */
    function _calcUpdatedAvg(ITwapWeightedObserver.PackedData memory data) internal view returns (uint128, uint128) {
        uint128 latestAcc = OBSERVER.getLatestAccumulator();
        uint128 avgValue = (latestAcc - data.observerCumuVal) /
            (uint64(block.timestamp) - data.lastObserved);
        return (avgValue, latestAcc);
    }

    /**
     * @notice Calculates the updated average value based on the latest accumulator and time elapsed.
     * @dev Utilizes the accumulator difference and the time passed to calculate the average.
     *      Uses the formula: (newAcc - acc0) / (now - t0).
     * @param data The packed data containing the last observed cumulative value and timestamp.
     * @return avgValue The updated average value.
     * @return latestAcc The latest accumulator value from the observer.
    */
    function _checkUpdatePeriod(ITwapWeightedObserver.PackedData memory data, uint256 period) internal view returns (bool) {
        return block.timestamp >= (data.lastObserved + period);
    }

    /**
     * @notice Observes and calculates the current average value using virtual weighting.
     * @dev Applies the new accumulator to skew the price proportionally to the time passed.
     *      The virtual average is calculated using the accumulator difference and weighted based on
     *      time elapsed since the last observation.
     * 
     *      It calculates a weighted mean of the last observed average and the virtual
     *      average based on the future weight, unless no time has passed since the last observation.
     * 
     * @return weightedMean The calculated weighted mean price.
     */
    function observe() external view returns (uint256) {
        ITwapWeightedObserver.PackedData memory data = OBSERVER.getData();

        // Here, we need to apply the new accumulator to skew the price in some way
        // The weight of the skew should be proportional to the time passed
        uint256 futureWeight = block.timestamp - data.lastObserved;

        if (futureWeight == 0) {
            return data.lastObservedAverage;
        }

        // A reference period is 7 days
        // For each second passed after update
        // Let's virtually sync TWAP
        // With a weight, that is higher, the more time has passed
        (uint128 virtualAvgValue, uint128 obsAcc) = _calcUpdatedAvg(data);

        uint256 period = OBSERVER.PERIOD();
        // Returns the virtual average directly if the update period has passed.
        if (_checkUpdatePeriod(data, period)) {
            // Return virtual
            return virtualAvgValue;
        }

        uint256 weightedAvg = uint256(data.lastObservedAverage) *
            (uint256(period) - uint256(futureWeight));
        uint256 weightedVirtual = uint256(virtualAvgValue) * (uint256(futureWeight));

        uint256 weightedMean = (weightedAvg + weightedVirtual) / period;

        return weightedMean;
    }
}
