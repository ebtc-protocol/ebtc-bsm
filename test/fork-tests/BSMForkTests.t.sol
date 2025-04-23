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
import {console} from "forge-std/console.sol";
contract BSMForkTests is Test {
    // Gather contracts
    IERC20 constant ebtc = IERC20(0x661c70333AA1850CcDBAe82776Bb436A0fCfeEfB);
    IERC20 constant cbBtc = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    address defaultGovernance = 0x2A095d44831C26cFB6aCb806A6531AE3CA32DBc1;
    ActivePoolObserver public activePoolObserver = ActivePoolObserver(0x1Ffe740F6f1655759573570de1E53E7b43E9f01a);
    AssetChainlinkAdapter public assetChainlinkAdapter = AssetChainlinkAdapter(0x0457B8e9dd5278fe89c97E0246A3c6Cf2C0d6034);
    DummyConstraint public dummyConstraint = DummyConstraint(0x581F1707c54F4f2f630b9726d717fA579d526976);
    Governor public authority = Governor(defaultGovernance);
    RateLimitingConstraint public rateLimitingConstraint = RateLimitingConstraint(0x6c289F91A8B7f622D8d5DcF252E8F5857CAc3E8B);
    OraclePriceConstraint public oraclePriceConstraint = OraclePriceConstraint(0xE66CD7ce741cF314Dc383d66315b61e1C9A3A15e);
    BaseEscrow public baseEscrow = BaseEscrow(0x686FdecC0572e30768331D4e1a44E5077B2f6083);
    EbtcBSM public ebtcBSM = EbtcBSM(0x828787A14fd4470Ef925Eefa8a56C88D85D4a06A);
    address cbBtcPool = 0xe8f7c89C5eFa061e340f2d2F206EC78FD8f7e124;
    address testAuthorizedAccount = address(0x1);
    address testUnAuthorizedAccount = address(0x2);
    address owner;
    //TODO I might not need all of this
    uint256 initBlock = 22313077;// Block after BSM was deployed
    uint256 submitBlock = 22327557;// Block where governance changes were submitted

    modifier prankDefaultGovernance() {
        vm.prank(owner);
        _;
    }

    //TODO assign roles
    //TODO setup should run bore everything not before each
      function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("RPC_URL"));
        vm.selectFork(forkId);
        owner = authority.owner();

        // give eBTC minter and burner roles to tester account
        setUserRole(testAuthorizedAccount, 1, true);//TODO verify if this is giving the correct roles
        setUserRole(testAuthorizedAccount, 2, true);
        setRoleName(15, "BSM: Governance");
        setRoleName(16, "BSM: AuthorizedUser");
        setRoleCapability(
        15,
        address(ebtcBSM),
        ebtcBSM.setFeeToBuy.selector,
        true
        );
        setRoleCapability(
        15,
        address(ebtcBSM),
        ebtcBSM.setFeeToSell.selector,
        true
        );
    }

    // Deployment tests
    function testDeployments() public {
        // Check values
        assertEq(address(ebtcBSM.escrow()), address(baseEscrow));
        assertEq(address(ebtcBSM.oraclePriceConstraint()), address(oraclePriceConstraint));
        assertEq(address(ebtcBSM.rateLimitingConstraint()), address(rateLimitingConstraint));
        assertEq(address(ebtcBSM.buyAssetConstraint()), address(dummyConstraint));
        assertEq(address(ebtcBSM.ASSET_TOKEN()), address(cbBtc));
        assertEq(address(ebtcBSM.EBTC_TOKEN()), address(ebtc));

        // Check initialization
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
        uint256 amount = cbBtc.balanceOf(cbBtcPool) / 4;
        // Basic sell
        vm.prank(cbBtcPool);// Fund account
        cbBtc.transfer(testAuthorizedAccount, amount);

        assertEq(cbBtc.balanceOf(testAuthorizedAccount), amount);
        assertEq(ebtc.balanceOf(testAuthorizedAccount), 0);

        vm.expectEmit();
        emit IEbtcBSM.AssetSold(amount, amount, 0);

        vm.prank(testAuthorizedAccount);
        assertEq(ebtcBSM.sellAsset(amount, testAuthorizedAccount, 0), amount);

        assertEq(ebtcBSM.totalMinted(), amount);
        assertEq(baseEscrow.totalAssetsDeposited(), amount);

        assertEq(cbBtc.balanceOf(testAuthorizedAccount), 0);
        assertEq(ebtc.balanceOf(testAuthorizedAccount), amount);
        assertEq(cbBtc.balanceOf(address(ebtcBSM.escrow())), amount);

        assertEq(ebtcBSM.totalMinted(), baseEscrow.totalAssetsDeposited());
        // Basic buy
        assertEq(ebtcBSM.previewBuyAsset(amount), amount);

        vm.recordLogs();
        vm.prank(testAuthorizedAccount);

        assertEq(ebtcBSM.buyAsset(amount, testAuthorizedAccount, 0), amount);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("AssetBought(uint256,uint256,uint256)"));

        assertEq(cbBtc.balanceOf(testAuthorizedAccount), amount);
        assertEq(ebtc.balanceOf(testAuthorizedAccount), 0);
    }
    // Helpers TODO: find a way to use the existing ones
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