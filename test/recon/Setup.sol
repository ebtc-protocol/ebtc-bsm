// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "./managers/ActorManager.sol";
import {AssetManager} from "./managers/AssetManager.sol";

import {BSMBase} from "../BSMTestBase.sol";

abstract contract Setup is BaseSetup, BSMBase, ActorManager, AssetManager {
    address second_actor = address(0x411c3);
    bool hasMigrated;

    // CONFIG
    bool ALLOWS_REKT = bool(true);

    function setup() internal virtual override {
        BSMBase.baseSetup();

        // New Actor, beside address(this)
        _addActor(second_actor);

        // Add deployed assets to manager
        _addAsset(address(mockEbtcToken));
        _addAsset(address(mockAssetToken));
        _enableAsset(address(mockEbtcToken));

        // TODO: Standardize Mint and allowances to all actors
        mockAssetToken.mint(second_actor, type(uint88).max);
        mockEbtcToken.mint(second_actor, type(uint88).max);

        vm.prank(second_actor);
        mockAssetToken.approve(address(bsmTester), type(uint256).max);
        vm.prank(second_actor);
        mockEbtcToken.approve(address(bsmTester), type(uint256).max);

        mockAssetToken.mint(address(this), type(uint88).max);
        mockEbtcToken.mint(address(this), type(uint88).max);
        mockAssetToken.approve(address(bsmTester), type(uint256).max);
        mockEbtcToken.approve(address(bsmTester), type(uint256).max);
    }

    // NOTE: LIMITATION You can use these modifier only for one call, so use them for BASIC TARGETS
    modifier asAdmin() {
        vm.prank(address(defaultGovernance));
        _;
    }

    modifier asTechops() {
        vm.prank(address(techOpsMultisig));
        _;
    }

    modifier asActor() {
        vm.prank(_getActor());
        _;
    }

    modifier stateless() {
        _;
        revert("stateless");
    }
}
