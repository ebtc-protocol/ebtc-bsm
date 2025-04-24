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

    ActivePoolObserver public activePoolObserver = ActivePoolObserver(0x1Ffe740F6f1655759573570de1E53E7b43E9f01a);
    AssetChainlinkAdapter public assetChainlinkAdapter = AssetChainlinkAdapter(0x0457B8e9dd5278fe89c97E0246A3c6Cf2C0d6034);
    DummyConstraint public dummyConstraint = DummyConstraint(0x581F1707c54F4f2f630b9726d717fA579d526976);
    Governor public authority = Governor(0x2A095d44831C26cFB6aCb806A6531AE3CA32DBc1);
    RateLimitingConstraint public rateLimitingConstraint = RateLimitingConstraint(0x6c289F91A8B7f622D8d5DcF252E8F5857CAc3E8B);
    OraclePriceConstraint public oraclePriceConstraint = OraclePriceConstraint(0xE66CD7ce741cF314Dc383d66315b61e1C9A3A15e);
    BaseEscrow public baseEscrow = BaseEscrow(0x686FdecC0572e30768331D4e1a44E5077B2f6083);
    EbtcBSM public ebtcBSM = EbtcBSM(0x828787A14fd4470Ef925Eefa8a56C88D85D4a06A);
    address cbBtcPool = 0xe8f7c89C5eFa061e340f2d2F206EC78FD8f7e124;
    address testAuthorizedAccount = address(0x1);
    address owner;
    uint256 initBlock = 22319821;// Block where BSM and peripheral contracts were already deployed

    modifier prankDefaultGovernance() {
        vm.prank(owner);
        _;
    }

    //TODO setup should run before everything not before each
      function setUp() public {
        uint256 forkId = vm.createFork(vm.envString("RPC_URL"), initBlock);
        vm.selectFork(forkId);
        owner = authority.owner();

        // give eBTC minter and burner roles to tester account
        setUserRole(address(ebtcBSM), 1, true);
        setUserRole(address(ebtcBSM), 2, true);

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
        setRoleCapability(
            15,
            address(rateLimitingConstraint),
            rateLimitingConstraint.setMintingConfig.selector,
            true
        );
        // Give ebtc tech ops role 15
        setUserRole(testAuthorizedAccount, 15, true);
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

        // No minting configuration set
        RateLimitingConstraint.MintingConfig memory config = rateLimitingConstraint.getMintingConfig(address(ebtcBSM));

        assertEq(config.relativeCapBPS, 0);
        assertEq(config.absoluteCap, 0);
        assertEq(config.useAbsoluteCap, false);
    }

    // AUTH tests
    function testSecurity() public {
        vm.expectRevert("Auth: UNAUTHORIZED");
        rateLimitingConstraint.setMintingConfig(address(ebtcBSM), RateLimitingConstraint.MintingConfig(0, 0, false));
        
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
    }

    // Buy & Sell tests
    function testBuyAndSell() public {
        uint256 relativeCapBPS = 1000;
        uint256 totalEbtcSupply = activePoolObserver.observe();
        uint256 maxMint = (totalEbtcSupply * relativeCapBPS) / rateLimitingConstraint.BPS();//ebtc decimals
        uint256 amount = (maxMint / 4) * ebtcBSM.ASSET_TOKEN_PRECISION() / 1e18;// asset decimals
        uint256 ebtcAmount = amount * 1e18 / ebtcBSM.ASSET_TOKEN_PRECISION();

        // Basic sell
        vm.prank(cbBtcPool);// Fund account
        cbBtc.transfer(testAuthorizedAccount, amount);
        
        vm.prank(testAuthorizedAccount);
        cbBtc.approve(address(ebtcBSM), amount);

        assertEq(cbBtc.balanceOf(testAuthorizedAccount), amount);
        assertEq(ebtc.balanceOf(testAuthorizedAccount), 0);

        vm.prank(testAuthorizedAccount);
        rateLimitingConstraint.setMintingConfig(address(ebtcBSM), RateLimitingConstraint.MintingConfig(relativeCapBPS, 0, false));
        
        vm.expectEmit();
        emit IEbtcBSM.AssetSold(amount, ebtcAmount, 0);

        vm.prank(testAuthorizedAccount);
        uint256 sellResult = ebtcBSM.sellAsset(amount, testAuthorizedAccount, 0);
        assertEq(sellResult, ebtcAmount);

        // These 2 checks also check that ebtcBSM.totalMinted() == baseEscrow.totalAssetsDeposited()
        assertEq(ebtcBSM.totalMinted(), ebtcAmount);
        assertEq(baseEscrow.totalAssetsDeposited(), amount);

        assertEq(cbBtc.balanceOf(testAuthorizedAccount), 0);
        assertEq(ebtc.balanceOf(testAuthorizedAccount), ebtcAmount);
        assertEq(cbBtc.balanceOf(address(ebtcBSM.escrow())), amount);

        // Basic buy
        assertEq(ebtcBSM.previewBuyAsset(ebtcAmount), amount);

        vm.recordLogs();
        vm.prank(testAuthorizedAccount);

        assertEq(ebtcBSM.buyAsset(ebtcAmount, testAuthorizedAccount, 0), amount);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[1].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(entries[2].topics[0], keccak256("AssetBought(uint256,uint256,uint256)"));

        assertEq(cbBtc.balanceOf(testAuthorizedAccount), amount);
        assertEq(ebtc.balanceOf(testAuthorizedAccount), 0);
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
}