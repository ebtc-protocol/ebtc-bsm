// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {MockAssetOracle} from "./mocks/MockAssetOracle.sol";
import {MockActivePoolObserver} from "./mocks/MockActivePoolObserver.sol";
import "../src/Dependencies/Governor.sol";
import "../src/EbtcBSM.sol";
import "../src/OraclePriceConstraint.sol";
import "../src/RateLimitingConstraint.sol";
import "../src/DummyConstraint.sol";
import "../src/ERC4626Escrow.sol";
import "./mocks/MockAssetToken.sol";
import {vm} from "@chimera/Hevm.sol";

contract BSMBase {
    uint8 constant internal NUM_DECIMALS = 8;

    MockAssetToken internal mockAssetToken;
    ERC20Mock internal mockEbtcToken;
    ERC4626Mock internal externalVault;
    ERC4626Escrow internal escrow;
    MockAssetOracle internal mockAssetOracle;
    MockActivePoolObserver internal mockActivePoolObserver;
    OraclePriceConstraint internal oraclePriceConstraint;
    RateLimitingConstraint internal rateLimitingConstraint;
    EbtcBSM internal bsmTester;
    address internal testMinter;
    address internal testBuyer;
    Governor internal authority;
    address internal defaultGovernance;
    address internal defaultFeeRecipient;
    address internal techOpsMultisig;
    address internal testAuthorizedUser;

    /**
     * @notice Pranks the following call as defaultGovernance
     * @dev Hevm does not allow the usage of startPrank, this was created 
     * to be used in the wrapper methods that need to be called by this user
     */
    modifier prankDefaultGovernance() {
        vm.prank(defaultGovernance);
        _;
    }

    function _getAssetTokenAmount(uint256 units) internal returns (uint256) {
        return units * (10 ** mockAssetToken.decimals());
    }

    function _getEbtcAmount(uint256 units) internal returns (uint256) {
        return units * (10 ** mockEbtcToken.decimals());
    }

    function _mintAssetToken(address to, uint256 units) internal {
        mockAssetToken.mint(to, _getAssetTokenAmount(units));
    }

    function _mintEbtc(address to, uint256 units) internal {
        mockEbtcToken.mint(to, _getEbtcAmount(units));
    }

    function baseSetup(uint8 assetDecimals) internal virtual {
        defaultGovernance = vm.addr(0x123456);
        defaultFeeRecipient = vm.addr(0x234567);
        authority = new Governor(defaultGovernance);
        mockAssetToken = new MockAssetToken(assetDecimals);
        mockEbtcToken = new ERC20Mock();
        mockActivePoolObserver = new MockActivePoolObserver(mockEbtcToken);
        externalVault = new ERC4626Mock(address(mockAssetToken));
        mockAssetOracle = new MockAssetOracle(18);
        oraclePriceConstraint = new OraclePriceConstraint(
            address(mockAssetOracle),
            address(authority)
        );
        rateLimitingConstraint = new RateLimitingConstraint(
            address(mockActivePoolObserver),
            address(authority)
        );
        testMinter = vm.addr(0x11111);
        testBuyer = vm.addr(0x22222);
        testAuthorizedUser = vm.addr(0x33333);
        techOpsMultisig = 0x690C74AF48BE029e763E61b4aDeB10E06119D3ba;

        bsmTester = new EbtcBSM(
            address(mockAssetToken),
            address(oraclePriceConstraint),
            address(rateLimitingConstraint),
            address(new DummyConstraint()),
            address(mockEbtcToken),
            address(authority)
        );

        escrow = new ERC4626Escrow(
            address(externalVault),
            address(mockAssetToken),
            address(bsmTester),
            address(authority),
            address(defaultFeeRecipient)
        );
        
        bsmTester.initialize(address(escrow));

        // create initial ebtc supply
        mockEbtcToken.mint(defaultGovernance, 100000000000e18);
        mockAssetOracle.setPrice(1e18);
        mockAssetOracle.setUpdateTime(block.timestamp);

        vm.prank(testMinter);
        mockAssetToken.approve(address(bsmTester), type(uint256).max);
        vm.prank(testAuthorizedUser);
        mockAssetToken.approve(address(bsmTester), type(uint256).max);
        vm.prank(testAuthorizedUser);
        mockEbtcToken.approve(address(bsmTester), type(uint256).max);

        // give eBTC minter and burner roles to BSM tester
        setUserRole(address(bsmTester), 1, true);
        setUserRole(address(bsmTester), 2, true);
        setRoleName(15, "BSM: Governance");
        setRoleName(16, "BSM: AuthorizedUser");
        setRoleCapability(
            15,
            address(bsmTester),
            bsmTester.setFeeToBuy.selector,
            true
        );
        setRoleCapability(
            15,
            address(bsmTester),
            bsmTester.setFeeToSell.selector,
            true
        );
        setRoleCapability(
            15,
            address(bsmTester),
            bsmTester.updateEscrow.selector,
            true
        );
        setRoleCapability(
            15,
            address(bsmTester),
            bsmTester.pause.selector,
            true
        );
        setRoleCapability(
            15,
            address(bsmTester),
            bsmTester.unpause.selector,
            true
        );
        setRoleCapability(
            15,
            address(bsmTester),
            bsmTester.setOraclePriceConstraint.selector,
            true
        );
        setRoleCapability(
            15,
            address(bsmTester),
            bsmTester.setRateLimitingConstraint.selector,
            true
        );
        setRoleCapability(
            15,
            address(escrow),
            escrow.claimProfit.selector,
            true
        );
        setRoleCapability(
            15,
            address(escrow),
            escrow.claimTokens.selector,
            true
        );
        setRoleCapability(
            15,
            address(escrow),
            escrow.depositToExternalVault.selector,
            true
        );
        setRoleCapability(
            15,
            address(escrow),
            escrow.redeemFromExternalVault.selector,
            true
        );
        setRoleCapability(
            15,
            address(oraclePriceConstraint),
            oraclePriceConstraint.setMinPrice.selector,
            true
        );
        setRoleCapability(
            15,
            address(oraclePriceConstraint),
            oraclePriceConstraint.setOracleFreshness.selector,
            true
        );
        setRoleCapability(
            15,
            address(rateLimitingConstraint),
            rateLimitingConstraint.setMintingConfig.selector,
            true
        );
        // Give ebtc tech ops role 15
        setUserRole(techOpsMultisig, 15, true);
        setRoleCapability(
            16,
            address(bsmTester),
            bsmTester.sellAssetNoFee.selector,
            true
        );
        setRoleCapability(
            16,
            address(bsmTester),
            bsmTester.buyAssetNoFee.selector,
            true
        );
        // Give authorizedUser role 16
        setUserRole(testAuthorizedUser, 16, true);

        // Set minting cap to 10%
        vm.prank(techOpsMultisig);
        rateLimitingConstraint.setMintingConfig(address(bsmTester), RateLimitingConstraint.MintingConfig(1000, 0, false));
    }

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
