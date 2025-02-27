// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ActivePoolObserver} from "src/ActivePoolObserver.sol";
import {BSMDeployer} from "src/BSMDeployer.sol";
import {OraclePriceConstraint} from "../src/OraclePriceConstraint.sol";
import {ITwapWeightedObserver} from "src/Dependencies/ITwapWeightedObserver.sol";//TODO alphabet sort
import {tBTCChainlinkAdapter, AggregatorV3Interface} from "../src/tBTCChainlinkAdapter.sol";

/**
* @notice Deployer contract for the whole bsm system
* @dev Contract is ownable ensuring only the owner can trigger the system deployment
*/
contract Deployer is Script, Ownable {
    event ContractDeployed(address indexed bsm, address indexed escrow);//TODO

    constructor() Ownable(msg.sender) {}

    /** 
    * @notice Deploy function in charge of deploying the full bsm system.
    * @dev This function can only be called by the contract owner.
    * @param _observer The address of the ITwapWeightedObserver instance for managing time-weighted averages.
    * @param _assetOracle The address of the asset price oracle.
    * @param _authority The address of the governor.
    * @param _tBtcUsdClFeed The oracle feed address for tBTC to USD prices.
    * @param _btcUsdClFeed The oracle feed address for BTC to USD prices.
    * @param _assetToken The address of the asset token.
    * @param _ebtcToken The address of the eBTC token.
    * @param _feeRecipient The address of fees recipient.
    * @param _externalVault The address of the external vault for asset management.
    */
    function deploy(ITwapWeightedObserver _observer, address _assetOracle, address _authority, AggregatorV3Interface _tBtcUsdClFeed, AggregatorV3Interface _btcUsdClFeed, address _assetToken, address _ebtcToken, address _feeRecipient, address _externalVault) external onlyOwner {
        // Deploy Observer contract
        ActivePoolObserver observer = new ActivePoolObserver(_observer);
        // Deploy Constrains contracts
        OraclePriceConstraint oraclePriceConstraint = new OraclePriceConstraint(
            _assetOracle,
            _authority
        );

        RateLimitingConstraint rateLimitingConstraint = new RateLimitingConstraint(observer, _authority);

        // Deploy ChainlinkAdapter contract
        tBTCChainlinkAdapter adapter = new tBTCChainlinkAdapter(_tBtcUsdClFeed, _btcUsdClFeed);//TODO this needs to be reused?

        // Deploy Deployer contract
        BSMDeployer bsmDeployer = new BSMDeployer();

        // Call deployer contract
        bsmDeployer.deploy(_assetToken, oraclePriceConstraint, rateLimitingConstraint, _ebtcToken, _feeRecipient, _authority, _externalVault);


        // TODO broadcast
    }
}