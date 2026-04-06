// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {StakingVault} from "../src/StakingVault.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {ReputationSystem} from "../src/ReputationSystem.sol";
import {Escrow} from "../src/Escrow.sol";
import {DisputeResolver} from "../src/DisputeResolver.sol";
import {JobRegistry} from "../src/JobRegistry.sol";

/// @notice Deploys the full Undergrid protocol in dependency order and wires permissions.
///
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify
///
/// Required env vars:
///   DEPLOYER_PRIVATE_KEY   — deployer wallet
///   FEE_RECIPIENT          — address that receives protocol fees
///   ARBITRATOR             — address that can apply human arbitration outcomes
contract DeployScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        address arbitrator = vm.envAddress("ARBITRATOR");

        console.log("Deployer:      ", deployer);
        console.log("Fee recipient: ", feeRecipient);
        console.log("Arbitrator:    ", arbitrator);

        vm.startBroadcast(deployerKey);

        // 1. Deploy independent contracts
        StakingVault stakingVault = new StakingVault();
        console.log("StakingVault:  ", address(stakingVault));

        AgentRegistry agentRegistry = new AgentRegistry();
        console.log("AgentRegistry: ", address(agentRegistry));

        ReputationSystem reputation = new ReputationSystem();
        console.log("ReputationSystem:", address(reputation));

        // 2. Pre-compute JobRegistry address (deployed after Escrow + DisputeResolver)
        uint64 nonce = vm.getNonce(deployer);
        address jobRegistryAddr = vm.computeCreateAddress(deployer, nonce + 2);
        console.log("JobRegistry (predicted):", jobRegistryAddr);

        // 3. Deploy Escrow pointing to predicted JobRegistry
        Escrow escrow = new Escrow(jobRegistryAddr);
        console.log("Escrow:        ", address(escrow));

        // 4. Deploy DisputeResolver
        DisputeResolver disputeResolver = new DisputeResolver(
            jobRegistryAddr,
            address(stakingVault),
            address(reputation),
            address(agentRegistry),
            arbitrator
        );
        console.log("DisputeResolver:", address(disputeResolver));

        // 5. Deploy JobRegistry (must match predicted address)
        JobRegistry jobRegistry = new JobRegistry(
            address(escrow),
            address(reputation),
            address(disputeResolver),
            address(stakingVault),
            feeRecipient
        );
        require(address(jobRegistry) == jobRegistryAddr, "Address prediction failed");
        console.log("JobRegistry:   ", address(jobRegistry));

        // 6. Wire permissions
        reputation.setAuthorized(address(jobRegistry), true);
        reputation.setAuthorized(address(disputeResolver), true);
        stakingVault.setAuthorized(address(disputeResolver), true);

        console.log("Permissions configured.");

        vm.stopBroadcast();

        _printAddresses(
            address(stakingVault),
            address(agentRegistry),
            address(reputation),
            address(escrow),
            address(disputeResolver),
            address(jobRegistry)
        );
    }

    function _printAddresses(
        address stakingVault,
        address agentRegistry,
        address reputation,
        address escrow,
        address disputeResolver,
        address jobRegistry
    ) internal pure {
        console.log("\n=== Deployment Summary ===");
        console.log("StakingVault:    ", stakingVault);
        console.log("AgentRegistry:   ", agentRegistry);
        console.log("ReputationSystem:", reputation);
        console.log("Escrow:          ", escrow);
        console.log("DisputeResolver: ", disputeResolver);
        console.log("JobRegistry:     ", jobRegistry);
        console.log("==========================\n");
    }
}
