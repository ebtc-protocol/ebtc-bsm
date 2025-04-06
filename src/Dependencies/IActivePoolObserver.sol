// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

interface IActivePoolObserver {
    function observe() external view returns (uint256);
}
