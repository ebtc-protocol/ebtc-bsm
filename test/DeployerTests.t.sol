// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../scripts/Deployer.s.sol";
import {IActivePoolObserver} from "../src/Dependencies/IActivePoolObserver.sol";

contract DeployerTests is Test {
    DeployScript.DeploymentConfig config;
    address constant activePoolAddress = 0x6dBDB6D420c110290431E863A1A978AE53F69ebC;
    address constant ebtc = 0x661c70333AA1850CcDBAe82776Bb436A0fCfeEfB;
    IActivePoolObserver activePool = IActivePoolObserver(activePoolAddress);

    function setUp() public {//addresses on mainnet
        config = DeployScript.DeploymentConfig({
            observer: ITwapWeightedObserver(address(activePool)),
            authority: 0x2A095d44831C26cFB6aCb806A6531AE3CA32DBc1,  
            tBtcUsdClFeed: 0x8350b7De6a6a2C1368E7D4Bd968190e13E354297,
            btcUsdClFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c,
            assetToken: 0x18084fba666a33d37592fa2633fd49a74dd93a88,//tbtc
            ebtcToken: 0x661c70333AA1850CcDBAe82776Bb436A0fCfeEfB,  
            feeRecipient: 0xD4D1e77C69E7AA63D0E66a06df89A2AA5d3b1d9E, 
            externalVault: 0x1
        });
    }

    function testSecurity() public {
        vm.prank(0x1);
        expectRevert();
        script.deploy(config);
    }

    function testDeployment() public {
        DeployScript script = new DeployScript();
        script.deploy(config);
        // Assertions TODO
        //todo security check
        //todo events checks
        assertTrue(address(script.newContract()) != address(0), "Contract should be deployed");
    }
}