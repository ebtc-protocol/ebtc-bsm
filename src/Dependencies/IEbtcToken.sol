// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

interface IEbtcToken {
    function mint(address _account, uint256 _amount) external;
    function burn(address _account, uint256 _amount) external;
}
