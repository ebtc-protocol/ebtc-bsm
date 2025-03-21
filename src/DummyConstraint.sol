// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IMintingConstraint} from "./Dependencies/IMintingConstraint.sol";

/// @notice Dummy constraint used as a placeholder
contract DummyConstraint is IMintingConstraint {
    /// @notice Returns true
    function canMint(uint256 _amount, address _minter) external view returns (bool, bytes memory) {
        return (true, "");
    }
}
