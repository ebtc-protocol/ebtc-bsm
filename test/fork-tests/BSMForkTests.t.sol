// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "forge-std/Test.sol";

contract BSMForkTests is Test {
    // Gather contracts
    ActivePoolObserver public activePoolObserver = ActivePoolObserver(0x1ffe740f6f1655759573570de1e53e7b43e9f01a);
    AssetChainlinkAdapter public assetChainlinkAdapter = AssetChainlinkAdapter(0x0457B8e9dd5278fe89c97E0246A3c6Cf2C0d6034);
    DummyConstraint public dummyConstraint = DummyConstraint(0x581F1707c54F4f2f630b9726d717fA579d526976);
    RateLimitingConstraint public rateLimitingConstraint = RateLimitingConstraint(0x6c289f91a8b7f622d8d5dcf252e8f5857cac3e8b);
    OraclePriceConstraint public oraclePriceConstraint = OraclePriceConstraint(0xe66cd7ce741cf314dc383d66315b61e1c9a3a15e);
    BaseEscrow public baseEscrow = BaseEscrow(0x686fdecc0572e30768331d4e1a44e5077b2f6083);
    EbtcBSM public ebtcBSM = EbtcBSM(0x828787a14fd4470ef925eefa8a56c88d85d4a06a);

    // Deployment tests
    function testDeployments() public {

    }

    // AUTH tests
    function testSecurity() public {

    }
    // Buy & Sell tests
    function testBuyAndSell() public {

    }
}