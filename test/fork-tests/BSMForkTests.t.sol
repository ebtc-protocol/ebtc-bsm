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
import "../mocks/MockAssetToken.sol";

contract BSMForkTests is Test {
    // Gather contracts
    IERC20 constant ebtc = IERC20(0x661c70333AA1850CcDBAe82776Bb436A0fCfeEfB);
    IERC20 constant cbBtc = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);

    ActivePoolObserver public activePoolObserver = ActivePoolObserver(0x1Ffe740F6f1655759573570de1E53E7b43E9f01a);
    AssetChainlinkAdapter public assetChainlinkAdapter = AssetChainlinkAdapter(0x0457B8e9dd5278fe89c97E0246A3c6Cf2C0d6034);
    DummyConstraint public dummyConstraint = DummyConstraint(0x581F1707c54F4f2f630b9726d717fA579d526976);
    Governor public authority = Governor(0x2A095d44831C26cFB6aCb806A6531AE3CA32DBc1);
    RateLimitingConstraint public rateLimitingConstraint = RateLimitingConstraint(0x6c289F91A8B7f622D8d5DcF252E8F5857CAc3E8B);
    OraclePriceConstraint public oraclePriceConstraint = OraclePriceConstraint(0xE66CD7ce741cF314Dc383d66315b61e1C9A3A15e);
    BaseEscrow public baseEscrow = BaseEscrow(0x686FdecC0572e30768331D4e1a44E5077B2f6083);
    EbtcBSM public ebtcBSM = EbtcBSM(0x828787A14fd4470Ef925Eefa8a56C88D85D4a06A);
    address cbBtcPool = 0xe8f7c89C5eFa061e340f2d2F206EC78FD8f7e124;
    address bsmAdmin = 0xaDDeE229Bd103bb5B10C3CdB595A01c425dd3264;
    address mintingManager = 0x690C74AF48BE029e763E61b4aDeB10E06119D3ba;
    
    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("RPC_URL"));
        vm.selectFork(forkId);
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
        assertUserRole(1, address(ebtcBSM));
        assertUserRole(2, address(ebtcBSM));

        // Check initialization
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        ebtcBSM.initialize(address(baseEscrow));

        // No minting configuration set
        RateLimitingConstraint.MintingConfig memory config = rateLimitingConstraint.getMintingConfig(address(ebtcBSM));

        assertEq(config.relativeCapBPS, 0);
        assertEq(config.absoluteCap, 0);
        assertEq(config.useAbsoluteCap, false);
    }

    // Buy & Sell tests
    function testBuyAndSell() public {
        uint256 relativeCapBPS = 1000;
        uint256 totalEbtcSupply = ebtc.totalSupply();
        uint256 maxMint = (totalEbtcSupply * relativeCapBPS) / rateLimitingConstraint.BPS();//ebtc decimals
        uint256 amount = (maxMint / 4) * ebtcBSM.ASSET_TOKEN_PRECISION() / 1e18;// asset decimals
        uint256 ebtcAmount = amount * 1e18 / ebtcBSM.ASSET_TOKEN_PRECISION();

        // Basic sell
        vm.prank(cbBtcPool);// Fund account
        cbBtc.transfer(bsmAdmin, amount);
        
        vm.prank(bsmAdmin);
        cbBtc.approve(address(ebtcBSM), amount);

        assertEq(cbBtc.balanceOf(bsmAdmin), amount);
        assertEq(ebtc.balanceOf(bsmAdmin), 0);
        
        vm.prank(mintingManager);
        rateLimitingConstraint.setMintingConfig(address(ebtcBSM), RateLimitingConstraint.MintingConfig(relativeCapBPS, 0, false));
        
        vm.expectEmit();
        emit IEbtcBSM.AssetSold(amount, ebtcAmount, 0);

        vm.prank(bsmAdmin);
        uint256 sellResult = ebtcBSM.sellAsset(amount, bsmAdmin, 0);
        assertEq(sellResult, ebtcAmount);

        // These 2 checks also check that ebtcBSM.totalMinted() == baseEscrow.totalAssetsDeposited()
        assertEq(ebtcBSM.totalMinted(), ebtcAmount);
        assertEq(baseEscrow.totalAssetsDeposited(), amount);

        assertEq(cbBtc.balanceOf(bsmAdmin), 0);
        assertEq(ebtc.balanceOf(bsmAdmin), ebtcAmount);
        assertEq(cbBtc.balanceOf(address(ebtcBSM.escrow())), amount);

        // Basic buy
        assertEq(ebtcBSM.previewBuyAsset(ebtcAmount), amount);

        vm.recordLogs();
        vm.prank(bsmAdmin);

        assertEq(ebtcBSM.buyAsset(ebtcAmount, bsmAdmin, 0), amount);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("AssetBought(uint256,uint256,uint256)"));

        assertEq(cbBtc.balanceOf(bsmAdmin), amount);
        assertEq(ebtc.balanceOf(bsmAdmin), 0);
    }

    // AUTH tests
    function testSecurity() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        rateLimitingConstraint.setMintingConfig(address(ebtcBSM), RateLimitingConstraint.MintingConfig(0, 0, false));

        vm.expectRevert("Auth: UNAUTHORIZED");
        oraclePriceConstraint.setMinPrice(0);

        vm.expectRevert("Auth: UNAUTHORIZED");
        oraclePriceConstraint.setOracleFreshness(0);
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.sellAssetNoFee(0, address(1), 0);
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.buyAssetNoFee(0, address(1), 0); 
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.setFeeToSell(0);
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.setFeeToBuy(0);
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.setRateLimitingConstraint(address(1));
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.setOraclePriceConstraint(address(1)); 
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.setBuyAssetConstraint(address(1)); 
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.updateEscrow(address(1));
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.pause();
        
        vm.expectRevert("Auth: UNAUTHORIZED");
        ebtcBSM.unpause();

        vm.expectRevert("Auth: UNAUTHORIZED");
        baseEscrow.claimProfit();

        vm.expectRevert("Auth: UNAUTHORIZED");
        baseEscrow.claimTokens(address(1), 0);
    }

    function testAdminRole() public {
        address user = bsmAdmin;
        uint8 roleId = 15;
        bytes4[] memory capabilities = new bytes4[](4);
        capabilities[0] = ebtcBSM.updateEscrow.selector;
        capabilities[1] = ebtcBSM.setOraclePriceConstraint.selector;
        capabilities[2] = ebtcBSM.setRateLimitingConstraint.selector;
        capabilities[3] = ebtcBSM.setBuyAssetConstraint.selector;

        assertUserRole(roleId, user);
        assertRoleName(roleId, "BSM: Admin");

        assertRoleCapabilities(roleId, capabilities, address(ebtcBSM));
        assertUserCapabilities(user, capabilities, address(ebtcBSM));
        
        DummyConstraint dummy = new DummyConstraint();

        vm.prank(user);
        ebtcBSM.updateEscrow(address(dummy));
        vm.prank(user);
        ebtcBSM.setOraclePriceConstraint(address(dummy));
        vm.prank(user);
        ebtcBSM.setRateLimitingConstraint(address(dummy));
        vm.prank(user);
        ebtcBSM.setBuyAssetConstraint(address(dummy));
        
    }

    function testFeeMngRole() public {
        address user = 0xE2F2D9e226e5236BeC4531FcBf1A22A7a2bD0602;
        uint8 roleId = 16;
        bytes4[] memory capabilities = new bytes4[](2);
        capabilities[0] = ebtcBSM.setFeeToSell.selector;
        capabilities[1] = ebtcBSM.setFeeToBuy.selector;

        assertRoleName(roleId, "BSM: Fee Manager");
        assertUserRole(roleId, user);
        assertRoleCapabilities(roleId, capabilities, address(ebtcBSM));

        assertUserCapabilities(user, capabilities, address(ebtcBSM));

        vm.prank(user);
        ebtcBSM.setFeeToSell(1);
        vm.prank(user);
        ebtcBSM.setFeeToBuy(1);
    }

    function testPauserRole() public {
        address user = 0xB3d3B6482fb50C82aa042A710775c72dfa23F7B4;
        uint8 roleId = 17;
        bytes4[] memory capabilities = new bytes4[](2);
        capabilities[0] =  ebtcBSM.pause.selector;
        capabilities[1] = ebtcBSM.unpause.selector;

        assertUserRole(roleId, user);
        assertRoleName(roleId, "BSM: Pauser");

        assertRoleCapabilities(roleId, capabilities, address(ebtcBSM));

        assertUserCapabilities(user, capabilities, address(ebtcBSM));

        vm.prank(user);
        ebtcBSM.pause();
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        ebtcBSM.previewSellAsset(1);

        vm.prank(user);
        ebtcBSM.unpause();

        ebtcBSM.previewSellAsset(1);
    }

    function testEscrowMngRole(uint256 amount) public {
        uint8 roleId = 18;
        bytes4[] memory capabilities = new bytes4[](2);
        capabilities[0] = baseEscrow.claimProfit.selector;
        capabilities[1] = baseEscrow.claimTokens.selector;

        assertUserRole(roleId, mintingManager);
        assertRoleName(roleId, "BSM: Escrow Manager");

        assertRoleCapabilities(roleId, capabilities, address(baseEscrow));

        assertUserCapabilities(mintingManager, capabilities, address(baseEscrow));

        MockAssetToken mockToken = new MockAssetToken(18);
        
        // Sending tokens
        mockToken.mint(address(baseEscrow), amount);
        vm.prank(mintingManager);
        baseEscrow.claimProfit();// No profit yet but should not revert
        
        vm.prank(mintingManager);
        baseEscrow.claimTokens(address(mockToken), amount);
        assertEq(mockToken.balanceOf(address(baseEscrow)), 0);
    }

    function testConstraintMngRole() public {
        uint8 roleId = 19;
        bytes4[] memory oracleCapabilities = new bytes4[](2);
        oracleCapabilities[0] = oraclePriceConstraint.setMinPrice.selector;
        oracleCapabilities[1] = oraclePriceConstraint.setOracleFreshness.selector;
        bytes4[] memory mintCapabilities = new bytes4[](1);
        mintCapabilities[0] = rateLimitingConstraint.setMintingConfig.selector;

        assertUserRole(roleId, mintingManager);
        assertRoleName(roleId, "BSM: Constraint Manager");

        assertRoleCapabilities(roleId, oracleCapabilities, address(oraclePriceConstraint));
        assertUserCapabilities(mintingManager, oracleCapabilities, address(oraclePriceConstraint));

        assertRoleCapabilities(roleId, mintCapabilities, address(rateLimitingConstraint));
        assertUserCapabilities(mintingManager, mintCapabilities, address(rateLimitingConstraint));

        vm.prank(mintingManager);
        oraclePriceConstraint.setMinPrice(9000);

        vm.prank(mintingManager);
        oraclePriceConstraint.setOracleFreshness(1000);
    }

    function testAuthUserRole() public {
        uint8 roleId = 20;
        bytes4[] memory capabilities = new bytes4[](2);
        capabilities[0] = ebtcBSM.sellAssetNoFee.selector;
        capabilities[1] = ebtcBSM.buyAssetNoFee.selector;

        assertRoleName(roleId, "BSM: Authorized User");

        assertRoleCapabilities(roleId, capabilities, address(ebtcBSM));
    }

    function assertUserRole(uint8 roleId, address user) internal {
        assertTrue(authority.doesUserHaveRole(user, roleId));
    }

    function assertRoleName(uint8 roleId, string memory name) internal {
        assertEq(authority.getRoleName(roleId), name);
    }

    function assertRoleCapabilities(uint8 roleId, bytes4[] memory capabilities, address target) internal {
        for(uint i = 0;i < capabilities.length;i++){
            assertTrue(authority.doesRoleHaveCapability(roleId, target, capabilities[i]));
        }
    }

    function assertUserCapabilities(address user, bytes4[] memory capabilities, address target) internal {
        for(uint i = 0;i < capabilities.length;i++){
            assertTrue(authority.canCall(user, target, capabilities[i]));
        }
    }

}