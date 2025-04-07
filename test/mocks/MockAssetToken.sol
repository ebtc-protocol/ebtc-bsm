// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MockAssetToken is ERC20Mock {
    uint8 internal numDecimals;

    constructor(uint8 _decimals) {
        numDecimals = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return numDecimals;
    }
}