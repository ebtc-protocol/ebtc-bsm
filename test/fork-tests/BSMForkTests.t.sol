// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/ActivePoolObserver.sol";
import "../../src/AssetChainlinkAdapter.sol";
import "../../src/DummyConstraint.sol";
import "../../src/ERC4626Escrow.sol";
import "../../src/EbtcBSM.sol";
import "../../src/Dependencies/Governor.sol";
import "../../src/OraclePriceConstraint.sol";
import "../../src/RateLimitingConstraint.sol";

contract BSMForkTests is Test {
    // Gather contracts
    address defaultGovernance = 0x2A095d44831C26cFB6aCb806A6531AE3CA32DBc1;
    ActivePoolObserver public activePoolObserver = ActivePoolObserver(0x1Ffe740F6f1655759573570de1E53E7b43E9f01a);
    AssetChainlinkAdapter public assetChainlinkAdapter = AssetChainlinkAdapter(0x0457B8e9dd5278fe89c97E0246A3c6Cf2C0d6034);
    DummyConstraint public dummyConstraint = DummyConstraint(0x581F1707c54F4f2f630b9726d717fA579d526976);
    Governor public authority = Governor(defaultGovernance);
    RateLimitingConstraint public rateLimitingConstraint = RateLimitingConstraint(0x6c289F91A8B7f622D8d5DcF252E8F5857CAc3E8B);
    OraclePriceConstraint public oraclePriceConstraint = OraclePriceConstraint(0xE66CD7ce741cF314Dc383d66315b61e1C9A3A15e);
    BaseEscrow public baseEscrow = BaseEscrow(0x686FdecC0572e30768331D4e1a44E5077B2f6083);
    EbtcBSM public ebtcBSM = EbtcBSM(0x828787A14fd4470Ef925Eefa8a56C88D85D4a06A);
    address testAuthorizedAccount = address(0x1);
    //TODO I might not need all of this
    uint256 initBlock = 22313077;// Block after BSM was deployed
    uint256 submitBlock = 22327557;// Block where governance changes were submitted

    modifier prankDefaultGovernance() {
        vm.prank(defaultGovernance);
        _;
    }

    //TODO assign roles
      function setUp() public {
        uint256 forkId = vm.createFork(vm.rpcUrl("RPC_URL"));
        vm.selectFork(forkId);
        vm.startPrank(testAccount);

        // give eBTC minter and burner roles to tester account
        setUserRole(testAuthorizedAccount, 1, true);
        setUserRole(testAuthorizedAccount, 2, true);
        setRoleName(15, "BSM: Governance");
        setRoleName(16, "BSM: AuthorizedUser");
        setRoleCapability(
        15,
        address(ebtcBSM),
        bsmTester.setFeeToBuy.selector,
        true
        );
        setRoleCapability(
        15,
        address(ebtcBSM),
        bsmTester.setFeeToSell.selector,
        true
        );
    }

    // Deployment tests
    function testDeployments() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        ebtcBSM.initialize(address(baseEscrow));
    }

    // AUTH tests
    function testSecurity() public {
        // test roles
        // test pause
    }
    // Buy & Sell tests
    function testBuyAndSell() public {
        // Basic sell
        // basic buy

    }
    // Helpers
    function setUserRole(address _user, uint8 _role, bool _enabled) internal prankDefaultGovernance {
        authority.setUserRole(_user, _role, _enabled);
    }
    
    function setRoleCapability(uint8 _role,
            address _target,
            bytes4 _functionSig,
            bool _enabled) internal prankDefaultGovernance {
        authority.setRoleCapability(
            _role,
            _target,
            _functionSig,
            _enabled
        );
    }

    function setRoleName(uint8 _role, string memory _roleName) internal prankDefaultGovernance {
        authority.setRoleName(_role, _roleName);
    }
}