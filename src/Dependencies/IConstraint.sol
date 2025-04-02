// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.25;

interface IConstraint {
    event ConstraintUpdated(address indexed oldConstraint, address indexed newConstraint);

    error ConstraintCheckFailed(address constraint, uint256 amount, address bsm, bytes errData);

    function canProcess(uint256 _amount, address _bsm) external view returns (bool, bytes memory);
}
