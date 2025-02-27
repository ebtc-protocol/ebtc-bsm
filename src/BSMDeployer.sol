// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.25;

import "./EbtcBSM.sol";
import "./ERC4626Escrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BSMDeployer is Ownable {
    event ContractDeployed(address indexed bsm, address indexed escrow);

    constructor() Ownable(msg.sender) {}

    /** 
    * @notice Deploy the BSM contract and the Escrow in a single transaction.
    * @dev Initializes the bsm with the recently deployed escrow, prevents users from calling the bsm 
    * until initialized.
    */
    function deploy(
        address _assetToken,
        address _oraclePriceConstraint,
        address _rateLimitingConstraint,
        address _ebtcToken,
        address _feeRecipient,
        address _governance,
        address _externalVault
    ) external onlyOwner {
        EbtcBSM bsm = new EbtcBSM(
            address(_assetToken),
            address(_oraclePriceConstraint),
            address(_rateLimitingConstraint),
            address(_ebtcToken),
            address(_governance)
        );

        ERC4626Escrow escrow = new ERC4626Escrow(
            address(_externalVault),
            address(_assetToken),
            address(bsm),
            address(_governance),
            address(_feeRecipient)
        );

        bsm.initialize(address(escrow));

        emit ContractDeployed(address(bsm), address(escrow));
    }
}
