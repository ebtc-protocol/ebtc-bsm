// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../scripts/Deployer.s.sol";
import {IActivePoolObserver} from "../src/Dependencies/IActivePoolObserver.sol";

// @dev Should only run against a fork
contract DeployerTests is Test {
    Deployer script;
    Deployer.DeploymentConfig config;
    address constant activePoolAddress = 0x6dBDB6D420c110290431E863A1A978AE53F69ebC;
    address constant ebtc = 0x661c70333AA1850CcDBAe82776Bb436A0fCfeEfB;
    IActivePoolObserver activePool = IActivePoolObserver(activePoolAddress);

    function setUp() public {//addresses on mainnet
        string memory rpcUrl = vm.envString("RPC_URL");
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);
        config = Deployer.DeploymentConfig({
            observer: ITwapWeightedObserver(address(activePool)),
            authority: 0x2A095d44831C26cFB6aCb806A6531AE3CA32DBc1,  
            tBtcUsdClFeed: AggregatorV3Interface(0x8350b7De6a6a2C1368E7D4Bd968190e13E354297),
            btcUsdClFeed: AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c),
            assetToken: 0x18084fbA666a33d37592fA2633fD49a74DD93a88,//tbtc
            ebtcToken: 0x661c70333AA1850CcDBAe82776Bb436A0fCfeEfB,  
            feeRecipient: 0xD4D1e77C69E7AA63D0E66a06df89A2AA5d3b1d9E, 
            externalVault: address(0x1)
        });
        
        script = new Deployer();
    }

    function testSecurity() public {
        vm.prank(address(0x2));
        vm.expectRevert();
        script.deploy(config);
    }

    function testDeployment() public {
        
        script.deploy(config);
        
        // Assertions TODO
        //todo security check
        //todo events checks
        assertTrue(address(script) != address(0), "Contract should be deployed");
    }
}