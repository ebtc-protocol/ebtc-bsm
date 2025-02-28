// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ActivePoolObserver} from "src/ActivePoolObserver.sol";
import {BSMDeployer} from "src/BSMDeployer.sol";
import {OraclePriceConstraint} from "../src/OraclePriceConstraint.sol";
import {RateLimitingConstraint} from "../src/RateLimitingConstraint.sol";
import {ITwapWeightedObserver} from "src/Dependencies/ITwapWeightedObserver.sol";//TODO alphabet sort
import {tBTCChainlinkAdapter, AggregatorV3Interface} from "../src/tBTCChainlinkAdapter.sol";

/**
* @notice Deployer contract for the whole bsm system
* @dev Contract is ownable ensuring only the owner can trigger the system deployment
*/
contract Deployer is Script, Ownable {
    /// @notice All the required information needed to make a deployment
    struct DeploymentConfig {
    ITwapWeightedObserver observer;// The address of the ITwapWeightedObserver instance for managing time-weighted averages.
    address assetOracle;    // The address of the asset price oracle.
    address authority;      // The address of the governor.
    AggregatorV3Interface tBtcUsdClFeed;// The oracle feed address for tBTC to USD prices.
    AggregatorV3Interface btcUsdClFeed;//  The oracle feed address for BTC to USD prices.
    address assetToken;     // The address of the asset token.
    address ebtcToken;      // The address of the eBTC token.
    address feeRecipient;   // The address of fees recipient.
    address externalVault;  // The address of the external vault for asset management.
}
    /// @notice event notifying of contracts deployments
    event ContractsDeployed(address indexed observer, address indexed oracleConstrain, address indexed rateConstrain, address indexed adapter) anonymous;

    constructor() Ownable(msg.sender) {}

    /** 
    * @notice Deploy function in charge of deploying the full bsm system.
    * @dev This function can only be called by the contract owner. To run it the ETH_MAINNET_RPC_URL or 
    * SEPOLIA_URL variables need to exists in a .env file, depending on the target chain.
    * @param config A DeploymentConfig with the needed information for deployment.
    */
    function deploy(DeploymentConfig calldata config) external onlyOwner {
        vm.startBroadcast();//TODO include PK
        // Deploy Observer contract
        ActivePoolObserver observer = new ActivePoolObserver(config.observer);
        // Deploy Constrains contracts
        OraclePriceConstraint oraclePriceConstraint = new OraclePriceConstraint(
            config.assetOracle,
            config.authority
        );

        RateLimitingConstraint rateLimitingConstraint = new RateLimitingConstraint(address(observer), config.authority);

        // Deploy ChainlinkAdapter contract
        tBTCChainlinkAdapter adapter = new tBTCChainlinkAdapter(config.tBtcUsdClFeed, config.btcUsdClFeed);

        emit ContractsDeployed(address(observer), address(oraclePriceConstraint), address(rateLimitingConstraint), address(adapter));
        // Deploy Deployer contract
        BSMDeployer bsmDeployer = new BSMDeployer();

        // Call deployer contract, this will emit an event on its own
        bsmDeployer.deploy(config.assetToken, address(oraclePriceConstraint), address(rateLimitingConstraint), config.ebtcToken, config.feeRecipient, config.authority, config.externalVault);

        vm.stopBroadcast();
    }
}