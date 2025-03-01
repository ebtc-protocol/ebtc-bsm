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
        assertTrue(address(script) != address(0));
    }

    function testSecurity() public {
        vm.prank(address(0x2));
        vm.expectRevert();
        script.deploy(config);
    }

    function testDeployment() public {
        vm.recordLogs();
        script.deploy(config);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertGt(entries.length, 0);

        // ContractsDeployed event is anonymous
        assertEq(entries[0].topics[0], keccak256("AuthorityUpdated(address,address)"));// Source: Oracle constrain
        assertEq(entries[1].topics[0], keccak256("AuthorityUpdated(address,address)"));// Source: Rate constrain
        //assertEq(entries[1].topics[0], keccak256("AuthorityUpdated(address,address)"));// Source: Deployer
        assertEq(entries[1].topics[0], keccak256("OwnershipTransferred(address,address)"));// Source: BSM Deployer
        assertEq(entries[1].topics[0], keccak256("AuthorityUpdated(address,address)"));// Source: BSM
        assertEq(entries[1].topics[0], keccak256("ContractDeployed(address,address)"));// Source: BSM Deployer

    }

    function testInvalidConfig() public {
        Deployer.DeploymentConfig memory badConfig;

        vm.expectRevert();
        script.deploy(badConfig);
    }
}