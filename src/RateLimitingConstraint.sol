// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {AuthNoOwner} from "./Dependencies/AuthNoOwner.sol";
import {IMintingConstraint} from "./Dependencies/IMintingConstraint.sol";
import {IActivePoolObserver} from "./Dependencies/IActivePoolObserver.sol";
import {IEbtcBSM} from "./Dependencies/IEbtcBSM.sol";

/// @title Rate Limiting Constraint for Minting
/// @notice This contract enforces rate-limiting constraints on minting operations to control inflation and supply of tokens.
contract RateLimitingConstraint is IMintingConstraint, AuthNoOwner {
    /// @notice Minting configuration structure for each minter
    struct MintingConfig {
        uint256 relativeCapBPS;  // Basis points of total supply allowed to mint
        uint256 absoluteCap;     // Hard cap on tokens that can be minted
        bool useAbsoluteCap;     // Flag to determine if absolute cap is used
    }

    /// @notice Basis points constant for percentage calculations
    uint256 public constant BPS = 10000;

    /// @notice Mapping of minter addresses to their minting configurations
    mapping(address => MintingConfig) internal mintingConfig;

    /// @notice The observer interface to interact with the active pool
    IActivePoolObserver public immutable ACTIVE_POOL_OBSERVER;

    /// @notice Event emitted when a minter's configuration is updated
    event MintingConfigUpdated(address indexed minter, MintingConfig oldConfig, MintingConfig newConfig);

    /// @notice Error thrown when a minting request exceeds the configured cap
    error AboveMintingCap(
        uint256 amountToMint,
        uint256 newTotalToMint,
        uint256 maxMint
    );

    /// @notice Contract constructor
    /// @param _activePoolObserver Address of the active pool observer
    /// @param _governance Address of the governance mechanism
    constructor(address _activePoolObserver, address _governance) {
        ACTIVE_POOL_OBSERVER = IActivePoolObserver(_activePoolObserver);
        _initializeAuthority(_governance);
    }

    /// @notice Checks if the minting amount is within the allowed cap for the minter
    /// @param _amount The amount to be minted
    /// @param _minter The address of the minter
    /// @return bool True if the minting is within the cap, false otherwise
    /// @return bytes Encoded error data if the mint is above the cap
    function canMint(uint256 _amount, address _minter) external view returns (bool, bytes memory) {
        MintingConfig memory cap = mintingConfig[_minter];
        uint256 maxMint;

        if (cap.useAbsoluteCap) {
            maxMint = cap.absoluteCap;
        } else {
            /// @notice ACTIVE_POOL.observe returns the eBTC TWAP total supply
            uint256 totalEbtcSupply = ACTIVE_POOL_OBSERVER.observe();
            maxMint = (totalEbtcSupply * cap.relativeCapBPS) / BPS;
        }

        uint256 newTotalToMint = IEbtcBSM(_minter).totalMinted() + _amount;

        if (newTotalToMint > maxMint) {
            return (false, abi.encodeWithSelector(AboveMintingCap.selector, _amount, newTotalToMint, maxMint));
        }

        return (true, "");
    }

    /// @notice Returns the minting configuration for a specific minter
    /// @param _minter The address of the minter
    /// @return MintingConfig The minting configuration of the minter
    function getMintingConfig(address _minter) external view returns (MintingConfig memory) {
        return mintingConfig[_minter];
    }

    /// @notice Sets the minting configuration for a specific minter
    /// @dev Can only be called by authorized users
    /// @param _minter The address of the minter
    /// @param _newMintingConfig The new minting configuration for the minter
    function setMintingConfig(address _minter, MintingConfig calldata _newMintingConfig) external requiresAuth {
        require(_newMintingConfig.relativeCapBPS <= BPS);
        emit MintingConfigUpdated(_minter, mintingConfig[_minter], _newMintingConfig);
        mintingConfig[_minter] = _newMintingConfig;
    }
}
