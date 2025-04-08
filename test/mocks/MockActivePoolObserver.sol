// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MockActivePoolObserver {
    ERC20Mock internal mockEbtcToken;

    constructor(ERC20Mock _mockEbtcToken) {
        mockEbtcToken = _mockEbtcToken;
    }

    function observe() external view returns (uint256) {
        return mockEbtcToken.totalSupply();
    }
}