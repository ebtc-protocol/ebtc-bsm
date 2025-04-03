// SPDX-License Identifier: MIT
pragma solidity 0.8.25;

interface ITwapWeightedObserver {
    // NOTE: Packing manually is cheaper, but this is simpler to understand and follow
    struct PackedData {
        // Slot 0
        // Seconds in a year: 3.154e+7
        /// @dev Accumulator value recorded for TWAP Observer until last update
        uint128 observerCumuVal; // 3.154e+7 * 80 * 100e27 = 2.5232e+38 | log_2(100e27 * 3.154e+7 * 80) = 127.568522171
        /// @dev Accumulator for TWAP globally
        uint128 accumulator; // 3.154e+7 * 80 * 100e27 = 2.5232e+38 | log_2(100e27 * 3.154e+7 * 80) = 127.568522171
        // NOTE: We can further compress this slot but we will not be able to use only one (see u72 impl)
        /// So what's the point of making the code more complex?

        // Slot 1
        /// @dev last update timestamp for TWAP Observer
        uint64 lastObserved; // Thousands of Years, if we use relative time we can use u32 | Relative to deploy time (as immutable)
        /// @dev last update timestamp for TWAP global track(spot) value
        uint64 lastAccrued; // Thousands of years
        // Expect eBTC debt to never surpass 100e27, which is 100 BILLION eBTC
        // log_2(100e27) = 96.3359147517 | log_2(100e27 / 1e18) = 36.5412090438
        // We could use a u64
        /// @dev average value since last observe
        uint128 lastObservedAverage;
    }

    function PERIOD() external view returns (uint256);

    function getLatestAccumulator() external view returns (uint128);
    function valueToTrack() external view returns (uint128);

    function getData() external view returns (PackedData memory);

    function observe() external returns (uint256);
}
