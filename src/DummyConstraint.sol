// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {IConstraint} from "./Dependencies/IConstraint.sol";

/// @notice Dummy constraint used as a placeholder
contract DummyConstraint is IConstraint {
    /// @notice Returns true
    function canProcess(uint256 _amount, address _bsm) external view returns (bool, bytes memory) {
        return (true, "");
    }
}
