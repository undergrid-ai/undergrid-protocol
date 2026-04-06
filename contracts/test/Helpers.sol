// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {JobRegistry} from "../src/JobRegistry.sol";
import {Escrow} from "../src/Escrow.sol";
import {StakingVault} from "../src/StakingVault.sol";
import {AgentRegistry} from "../src/AgentRegistry.sol";
import {ReputationSystem} from "../src/ReputationSystem.sol";
import {DisputeResolver} from "../src/DisputeResolver.sol";
import {IJobRegistry} from "../src/interfaces/IJobRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

/// @notice Base test helper that deploys and wires the full protocol.
abstract contract ProtocolHelpers is Test {
    // Protocol contracts
    Escrow internal escrow;
    StakingVault internal stakingVault;
    AgentRegistry internal agentRegistry;
    ReputationSystem internal reputation;
    DisputeResolver internal disputeResolver;
    JobRegistry internal jobRegistry;

    // Actors
    address internal requester = makeAddr("requester");
    address internal worker = makeAddr("worker");
    address internal verifier = makeAddr("verifier");
    address internal challenger = makeAddr("challenger");
    address internal arbitrator = makeAddr("arbitrator");
    address internal feeRecipient = makeAddr("feeRecipient");
    address internal voter1 = makeAddr("voter1");
    address internal voter2 = makeAddr("voter2");
    address internal voter3 = makeAddr("voter3");

    // Standard IPFS CIDs (random bytes32 standing in for real CIDs)
    bytes32 internal constant DESC_CID = keccak256("description");
    bytes32 internal constant INPUT_CID = keccak256("input");
    bytes32 internal constant SCHEMA_CID = keccak256("schema");
    bytes32 internal constant CRITERIA_CID = keccak256("criteria");
    bytes32 internal constant RESULT_CID = keccak256("result");
    bytes32 internal constant CAPS_CID = keccak256("capabilities");

    uint256 internal constant JOB_PAYMENT = 1 ether;
    uint256 internal constant VERIFIER_FEE = 0.1 ether;
    uint256 internal constant WORKER_STAKE = 0.1 ether;
    uint256 internal constant VERIFIER_STAKE = 0.1 ether;
    uint256 internal constant CHALLENGER_STAKE = 0.1 ether;

    function setUp() public virtual {
        // Deploy in dependency order
        stakingVault = new StakingVault();
        agentRegistry = new AgentRegistry();
        reputation = new ReputationSystem();

        // Escrow needs jobRegistry address — deploy jobRegistry first with placeholder, then replace
        // Instead we use a two-step: deploy Escrow pointing to a future address, deploy JobRegistry, verify
        // We compute the address of jobRegistry before deploying it.
        // Simpler: deploy Escrow with the actual address by predicting nonce.
        // Easiest approach for tests: deploy JobRegistry with a temporary escrow, then swap.
        // Actually cleanest: deploy Escrow with address(this) then update after — but Escrow is immutable.
        // Use vm.computeCreateAddress to pre-compute JobRegistry address.

        // escrow (nonce+0) and disputeResolver (nonce+1) are deployed before jobRegistry (nonce+2)
        uint64 currentNonce = vm.getNonce(address(this));
        address jobRegistryAddr = vm.computeCreateAddress(address(this), currentNonce + 2);

        escrow = new Escrow(jobRegistryAddr);

        disputeResolver = new DisputeResolver(
            jobRegistryAddr,
            address(stakingVault),
            address(reputation),
            address(agentRegistry),
            arbitrator
        );

        jobRegistry = new JobRegistry(
            address(escrow),
            address(reputation),
            address(disputeResolver),
            address(stakingVault),
            feeRecipient
        );

        require(address(jobRegistry) == jobRegistryAddr, "Address mismatch");

        // Authorize JobRegistry and DisputeResolver to write reputation
        reputation.setAuthorized(address(jobRegistry), true);
        reputation.setAuthorized(address(disputeResolver), true);

        // Authorize DisputeResolver to slash stakes
        stakingVault.setAuthorized(address(disputeResolver), true);

        // Fund actors
        vm.deal(requester, 100 ether);
        vm.deal(worker, 10 ether);
        vm.deal(verifier, 10 ether);
        vm.deal(challenger, 10 ether);
        vm.deal(voter1, 1 ether);
        vm.deal(voter2, 1 ether);
        vm.deal(voter3, 1 ether);

        // Stake for worker, verifier, challenger
        vm.prank(worker);
        stakingVault.stake{value: WORKER_STAKE}();

        vm.prank(verifier);
        stakingVault.stake{value: VERIFIER_STAKE}();

        vm.prank(challenger);
        stakingVault.stake{value: CHALLENGER_STAKE}();

        // Register verifier in AgentRegistry (needed for dispute voting)
        _registerAsVerifier(verifier);
        _registerAsVerifier(voter1);
        _registerAsVerifier(voter2);
        _registerAsVerifier(voter3);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _defaultJobSpec() internal view returns (IJobRegistry.JobSpec memory) {
        return IJobRegistry.JobSpec({
            descriptionCID: DESC_CID,
            inputCID: INPUT_CID,
            outputSchemaCID: SCHEMA_CID,
            successCriteriaCID: CRITERIA_CID,
            payment: JOB_PAYMENT,
            verifierFee: VERIFIER_FEE,
            bidDeadline: block.timestamp + 1 days,
            challengeWindow: 2 hours,
            disputeType: IJobRegistry.DisputeMechanism.MULTI_AGENT_CONSENSUS
        });
    }

    function _createJob() internal returns (uint256 jobId) {
        vm.prank(requester);
        jobId = jobRegistry.createJob{value: JOB_PAYMENT}(_defaultJobSpec());
    }

    function _createAndAcceptJob() internal returns (uint256 jobId) {
        jobId = _createJob();
        vm.prank(worker);
        jobRegistry.acceptJob(jobId, verifier);
    }

    function _createAcceptAndSubmit() internal returns (uint256 jobId) {
        jobId = _createAndAcceptJob();
        vm.prank(worker);
        jobRegistry.submitResult(jobId, RESULT_CID);
    }

    function _createAcceptSubmitVerify() internal returns (uint256 jobId) {
        jobId = _createAcceptAndSubmit();
        vm.prank(verifier);
        jobRegistry.attestVerification(jobId, true);
    }

    function _registerAsVerifier(address agent) internal {
        vm.deal(agent, vm.addr(1).balance + 1 ether);
        string[] memory taskTypes = new string[](1);
        taskTypes[0] = "verification";
        IAgentRegistry.AgentProfile memory profile = IAgentRegistry.AgentProfile({
            capabilitiesCID: CAPS_CID,
            taskTypes: taskTypes,
            pricePerJob: 0.01 ether,
            maxLatencySeconds: 3600,
            role: IAgentRegistry.AgentRole.VERIFIER,
            active: true,
            registeredAt: 0
        });
        vm.prank(agent);
        agentRegistry.registerAgent(profile);
    }
}
