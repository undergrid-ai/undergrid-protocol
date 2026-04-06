// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDisputeResolver} from "./interfaces/IDisputeResolver.sol";
import {IJobRegistry} from "./interfaces/IJobRegistry.sol";
import {IStakingVault} from "./interfaces/IStakingVault.sol";
import {IReputationSystem} from "./interfaces/IReputationSystem.sol";
import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";

/// @title DisputeResolver
/// @notice Handles challenges to submitted work results.
///
/// Flow for MULTI_AGENT_CONSENSUS:
///   1. Challenger calls raiseDispute() within the challenge window.
///   2. Active verifier agents cast votes via castVote().
///   3. After voting deadline, anyone calls resolveDispute() to tally.
///
/// Flow for HUMAN_ARBITRATION:
///   1. raiseDispute() is called.
///   2. requestArbitration() routes to off-chain oracle.
///   3. Trusted arbitrator calls applyArbitrationOutcome().
///
/// Flow for OPTIMISTIC:
///   Challenge window is the only protection — disputes go straight to
///   human arbitration since there is no verifier.
contract DisputeResolver is IDisputeResolver {
    uint256 public constant VOTING_DURATION = 24 hours;
    uint256 public constant MIN_VOTES_FOR_CONSENSUS = 3;
    uint256 public constant CHALLENGER_SLASH_AMOUNT = 0.005 ether; // slashed from worker if wrong
    uint256 public constant CHALLENGER_REWARD_AMOUNT = 0.005 ether; // challenger earns if right

    IJobRegistry public immutable jobRegistry;
    IStakingVault public immutable stakingVault;
    IReputationSystem public immutable reputation;
    IAgentRegistry public immutable agentRegistry;

    address public arbitrator;
    address public owner;

    mapping(uint256 => Dispute) private _disputes;
    mapping(uint256 => mapping(address => bool)) private _hasVoted;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyArbitrator() {
        if (msg.sender != arbitrator) revert NotAuthorized(msg.sender);
        _;
    }

    constructor(
        address _jobRegistry,
        address _stakingVault,
        address _reputation,
        address _agentRegistry,
        address _arbitrator
    ) {
        require(
            _jobRegistry != address(0) && _stakingVault != address(0) && _reputation != address(0)
                && _agentRegistry != address(0) && _arbitrator != address(0),
            "Zero address"
        );
        jobRegistry = IJobRegistry(_jobRegistry);
        stakingVault = IStakingVault(_stakingVault);
        reputation = IReputationSystem(_reputation);
        agentRegistry = IAgentRegistry(_agentRegistry);
        arbitrator = _arbitrator;
        owner = msg.sender;
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    function setArbitrator(address newArbitrator) external onlyOwner {
        require(newArbitrator != address(0), "Zero address");
        arbitrator = newArbitrator;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // -------------------------------------------------------------------------
    // Dispute lifecycle
    // -------------------------------------------------------------------------

    /// @notice Raise a dispute against a submitted result.
    ///         Can only be called during the challenge window (SUBMITTED state).
    function raiseDispute(uint256 jobId) external {
        if (_disputes[jobId].state != DisputeState.NONE) revert DisputeAlreadyExists(jobId);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);

        if (job.state != IJobRegistry.JobState.SUBMITTED) {
            revert ChallengeWindowExpired(jobId);
        }

        // Challenger must have stake
        require(stakingVault.meetsMinimum(msg.sender, CHALLENGER_REWARD_AMOUNT), "Insufficient challenger stake");

        DisputeState initialState = job.disputeType == IJobRegistry.DisputeMechanism.HUMAN_ARBITRATION
            || job.disputeType == IJobRegistry.DisputeMechanism.OPTIMISTIC
            ? DisputeState.AWAITING_ARBITRATION
            : DisputeState.VOTING;

        _disputes[jobId] = Dispute({
            jobId: jobId,
            challenger: msg.sender,
            state: initialState,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + VOTING_DURATION,
            workerWon: false,
            resolved: false
        });

        // Transition job to DISPUTED on-chain so challenge window is locked
        (bool ok,) = address(jobRegistry).call(
            abi.encodeWithSignature("markJobDisputed(uint256)", jobId)
        );
        require(ok, "State transition failed");

        emit DisputeRaised(jobId, msg.sender);

        if (initialState == DisputeState.AWAITING_ARBITRATION) {
            emit ArbitrationRequested(jobId);
        }
    }

    /// @notice Cast a vote on a disputed job (MULTI_AGENT_CONSENSUS disputes only).
    ///         Caller must be a registered active verifier.
    function castVote(uint256 jobId, bool supportsWorker) external {
        Dispute storage dispute = _disputes[jobId];
        if (dispute.state != DisputeState.VOTING) revert NoActiveDispute(jobId);
        if (block.timestamp > dispute.deadline) revert VotingDeadlinePassed(jobId);
        if (_hasVoted[jobId][msg.sender]) revert AlreadyVoted(jobId, msg.sender);

        bool isVerifier = agentRegistry.hasRole(msg.sender, IAgentRegistry.AgentRole.VERIFIER)
            || agentRegistry.hasRole(msg.sender, IAgentRegistry.AgentRole.BOTH);
        if (!isVerifier) revert NotEligibleVoter(msg.sender);

        _hasVoted[jobId][msg.sender] = true;

        if (supportsWorker) {
            dispute.votesFor += 1;
        } else {
            dispute.votesAgainst += 1;
        }

        emit VoteCast(jobId, msg.sender, supportsWorker);
    }

    /// @notice Tally votes and resolve a MULTI_AGENT_CONSENSUS dispute.
    ///         Can be called by anyone after the voting deadline.
    function resolveDispute(uint256 jobId) external {
        Dispute storage dispute = _disputes[jobId];
        if (dispute.state != DisputeState.VOTING) revert NoActiveDispute(jobId);

        uint256 totalVotes = dispute.votesFor + dispute.votesAgainst;

        // If not enough votes, escalate to human arbitration
        if (totalVotes < MIN_VOTES_FOR_CONSENSUS) {
            dispute.state = DisputeState.AWAITING_ARBITRATION;
            emit ArbitrationRequested(jobId);
            return;
        }

        bool workerWon = dispute.votesFor > dispute.votesAgainst;
        _finalizeDispute(jobId, workerWon);
    }

    /// @notice Request human arbitration for a VOTING dispute that stalled.
    function requestArbitration(uint256 jobId) external {
        Dispute storage dispute = _disputes[jobId];
        if (dispute.state != DisputeState.VOTING) revert NoActiveDispute(jobId);
        if (block.timestamp <= dispute.deadline) revert NotAuthorized(msg.sender);

        dispute.state = DisputeState.AWAITING_ARBITRATION;
        emit ArbitrationRequested(jobId);
    }

    /// @notice Trusted arbitrator applies outcome for human-arbitrated disputes.
    function applyArbitrationOutcome(uint256 jobId, bool workerWon) external onlyArbitrator {
        Dispute storage dispute = _disputes[jobId];
        if (dispute.state != DisputeState.AWAITING_ARBITRATION) revert NoActiveDispute(jobId);
        _finalizeDispute(jobId, workerWon);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    function getDispute(uint256 jobId) external view returns (Dispute memory) {
        return _disputes[jobId];
    }

    function hasVoted(uint256 jobId, address voter) external view returns (bool) {
        return _hasVoted[jobId][voter];
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    function _finalizeDispute(uint256 jobId, bool workerWon) internal {
        Dispute storage dispute = _disputes[jobId];
        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);

        dispute.workerWon = workerWon;
        dispute.resolved = true;
        dispute.state = DisputeState.RESOLVED;

        if (!workerWon) {
            // Slash worker stake; reward challenger
            if (stakingVault.meetsMinimum(job.worker, CHALLENGER_SLASH_AMOUNT)) {
                stakingVault.slash(job.worker, CHALLENGER_SLASH_AMOUNT, dispute.challenger);
            }
            reputation.recordDisputeLost(job.worker);
        } else {
            // Worker won: slash challenger stake as penalty for frivolous challenge
            if (stakingVault.meetsMinimum(dispute.challenger, CHALLENGER_REWARD_AMOUNT)) {
                stakingVault.slash(dispute.challenger, CHALLENGER_REWARD_AMOUNT, job.worker);
            }
            reputation.recordDisputeLost(dispute.challenger);
        }

        // Delegate payment outcome to JobRegistry
        // We cast to the concrete implementation to call applyDisputeOutcome
        // (not part of IJobRegistry interface to keep interface clean)
        (bool ok,) = address(jobRegistry).call(
            abi.encodeWithSignature("applyDisputeOutcome(uint256,bool)", jobId, workerWon)
        );
        require(ok, "Outcome application failed");

        emit DisputeResolved(jobId, workerWon);
    }
}
