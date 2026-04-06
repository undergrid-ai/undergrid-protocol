// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IJobRegistry} from "./interfaces/IJobRegistry.sol";
import {IEscrow} from "./interfaces/IEscrow.sol";
import {IReputationSystem} from "./interfaces/IReputationSystem.sol";
import {IDisputeResolver} from "./interfaces/IDisputeResolver.sol";
import {IStakingVault} from "./interfaces/IStakingVault.sol";

/// @title JobRegistry
/// @notice Core state machine for the Undergrid work exchange protocol.
///         Handles the full job lifecycle from creation through settlement.
///
/// State machine:
///   OPEN → ACCEPTED → SUBMITTED → VERIFIED → SETTLED
///                                          → DISPUTED → RESOLVED
///   OPEN → CANCELLED  (requester cancels before acceptance)
contract JobRegistry is IJobRegistry {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant PROTOCOL_FEE_BPS = 50; // 0.5% protocol fee
    uint256 public constant MIN_CHALLENGE_WINDOW = 1 hours;
    uint256 public constant MAX_CHALLENGE_WINDOW = 7 days;
    uint256 public constant MIN_WORKER_STAKE = 0.01 ether;
    uint256 public constant MIN_VERIFIER_STAKE = 0.01 ether;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    uint256 private _jobCount;
    address public immutable feeRecipient;

    IEscrow public immutable escrow;
    IReputationSystem public immutable reputation;
    IDisputeResolver public immutable disputeResolver;
    IStakingVault public immutable stakingVault;

    mapping(uint256 => Job) private _jobs;
    mapping(uint256 => bytes32) private _resultCIDs;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(
        address _escrow,
        address _reputation,
        address _disputeResolver,
        address _stakingVault,
        address _feeRecipient
    ) {
        if (
            _escrow == address(0) || _reputation == address(0) || _disputeResolver == address(0)
                || _stakingVault == address(0) || _feeRecipient == address(0)
        ) revert ZeroAddress();

        escrow = IEscrow(_escrow);
        reputation = IReputationSystem(_reputation);
        disputeResolver = IDisputeResolver(_disputeResolver);
        stakingVault = IStakingVault(_stakingVault);
        feeRecipient = _feeRecipient;
    }

    // -------------------------------------------------------------------------
    // External: Requester actions
    // -------------------------------------------------------------------------

    /// @notice Create a new job and lock payment in escrow.
    /// @dev msg.value must equal spec.payment (which includes verifierFee).
    function createJob(JobSpec calldata spec) external payable returns (uint256 jobId) {
        if (spec.payment == 0) revert InsufficientPayment(1, 0);
        if (msg.value < spec.payment) revert InsufficientPayment(spec.payment, msg.value);
        if (spec.verifierFee >= spec.payment) revert InsufficientPayment(spec.payment, spec.verifierFee);
        if (spec.bidDeadline <= block.timestamp) revert InvalidBidDeadline();
        if (spec.challengeWindow < MIN_CHALLENGE_WINDOW || spec.challengeWindow > MAX_CHALLENGE_WINDOW) {
            revert InvalidChallengeWindow();
        }

        jobId = ++_jobCount;

        _jobs[jobId] = Job({
            descriptionCID: spec.descriptionCID,
            inputCID: spec.inputCID,
            outputSchemaCID: spec.outputSchemaCID,
            successCriteriaCID: spec.successCriteriaCID,
            payment: spec.payment,
            verifierFee: spec.verifierFee,
            bidDeadline: spec.bidDeadline,
            challengeWindow: spec.challengeWindow,
            requester: msg.sender,
            worker: address(0),
            verifier: address(0),
            disputeType: spec.disputeType,
            state: JobState.OPEN,
            createdAt: block.timestamp,
            acceptedAt: 0,
            submittedAt: 0
        });

        // Refund overpayment before locking (keep only spec.payment)
        if (msg.value > spec.payment) {
            uint256 excess = msg.value - spec.payment;
            (bool ok,) = msg.sender.call{value: excess}("");
            require(ok, "Refund failed");
        }

        escrow.lockPayment{value: spec.payment}(jobId, msg.sender, spec.verifierFee);

        emit JobCreated(jobId, msg.sender, spec.payment);
    }

    /// @notice Cancel an OPEN job and refund payment.
    function cancelJob(uint256 jobId) external {
        Job storage job = _requireJob(jobId);
        if (job.requester != msg.sender) revert NotRequester(jobId, msg.sender);
        _requireState(jobId, job, JobState.OPEN);

        job.state = JobState.CANCELLED;
        escrow.refundPayment(jobId, msg.sender);

        emit JobCancelled(jobId);
    }

    // -------------------------------------------------------------------------
    // External: Worker actions
    // -------------------------------------------------------------------------

    /// @notice Accept an open job. Worker must have sufficient stake.
    /// @param verifier The address of the verifier agent for this job.
    function acceptJob(uint256 jobId, address verifier) external {
        Job storage job = _requireJob(jobId);
        _requireState(jobId, job, JobState.OPEN);

        if (block.timestamp > job.bidDeadline) revert BidDeadlinePassed(jobId);
        if (verifier == address(0)) revert ZeroAddress();
        if (!stakingVault.meetsMinimum(msg.sender, MIN_WORKER_STAKE)) {
            revert InsufficientPayment(MIN_WORKER_STAKE, stakingVault.getStake(msg.sender));
        }
        if (!stakingVault.meetsMinimum(verifier, MIN_VERIFIER_STAKE)) {
            revert InsufficientPayment(MIN_VERIFIER_STAKE, stakingVault.getStake(verifier));
        }

        job.worker = msg.sender;
        job.verifier = verifier;
        job.state = JobState.ACCEPTED;
        job.acceptedAt = block.timestamp;

        emit JobAccepted(jobId, msg.sender);
        emit VerifierAssigned(jobId, verifier);
    }

    /// @notice Submit work result. Starts the challenge window.
    /// @param resultCID IPFS CID of the result data.
    function submitResult(uint256 jobId, bytes32 resultCID) external {
        Job storage job = _requireJob(jobId);
        if (job.worker != msg.sender) revert NotWorker(jobId, msg.sender);
        _requireState(jobId, job, JobState.ACCEPTED);

        _resultCIDs[jobId] = resultCID;
        job.state = JobState.SUBMITTED;
        job.submittedAt = block.timestamp;

        emit ResultSubmitted(jobId, msg.sender, resultCID);
    }

    // -------------------------------------------------------------------------
    // External: Verifier actions
    // -------------------------------------------------------------------------

    /// @notice Verifier attests whether submitted work meets success criteria.
    function attestVerification(uint256 jobId, bool success) external {
        Job storage job = _requireJob(jobId);
        if (job.verifier != msg.sender) revert NotVerifier(jobId, msg.sender);
        _requireState(jobId, job, JobState.SUBMITTED);

        if (success) {
            job.state = JobState.VERIFIED;
            reputation.recordVerificationResult(msg.sender, true);
            emit JobVerified(jobId, msg.sender);
        } else {
            // Verifier says work failed — trigger dispute
            job.state = JobState.DISPUTED;
            reputation.recordVerificationResult(msg.sender, false);
            emit JobDisputed(jobId, msg.sender);
        }
    }

    // -------------------------------------------------------------------------
    // External: Settlement
    // -------------------------------------------------------------------------

    /// @notice Settle a verified job after the challenge window has elapsed.
    ///         Anyone can call this (keeper-friendly).
    function settleJob(uint256 jobId) external {
        Job storage job = _requireJob(jobId);
        _requireState(jobId, job, JobState.VERIFIED);

        if (block.timestamp < job.submittedAt + job.challengeWindow) {
            revert ChallengeWindowActive(jobId);
        }

        job.state = JobState.SETTLED;

        escrow.releasePayment(jobId, job.worker, job.verifier, feeRecipient, PROTOCOL_FEE_BPS);

        uint256 latency = job.submittedAt - job.acceptedAt;
        reputation.recordJobCompleted(job.worker, latency);

        emit JobSettled(jobId, job.worker, job.payment);
    }

    // -------------------------------------------------------------------------
    // External: Dispute integration
    // -------------------------------------------------------------------------

    /// @notice Called by DisputeResolver when a dispute is raised.
    ///         Transitions job from SUBMITTED → DISPUTED so the challenge window is locked.
    function markJobDisputed(uint256 jobId) external {
        if (msg.sender != address(disputeResolver)) revert NotVerifier(jobId, msg.sender);
        Job storage job = _requireJob(jobId);
        _requireState(jobId, job, JobState.SUBMITTED);
        job.state = JobState.DISPUTED;
        emit JobDisputed(jobId, msg.sender);
    }

    /// @notice Called by DisputeResolver when a dispute is resolved.
    function applyDisputeOutcome(uint256 jobId, bool workerWon) external {
        if (msg.sender != address(disputeResolver)) revert NotVerifier(jobId, msg.sender);

        Job storage job = _requireJob(jobId);
        _requireState(jobId, job, JobState.DISPUTED);

        job.state = JobState.RESOLVED;

        if (workerWon) {
            escrow.releasePayment(jobId, job.worker, job.verifier, feeRecipient, PROTOCOL_FEE_BPS);
            reputation.recordJobCompleted(job.worker, block.timestamp - job.acceptedAt);
        } else {
            escrow.refundPayment(jobId, job.requester);
            reputation.recordJobFailed(job.worker);
            reputation.recordDisputeLost(job.worker);
        }

        emit JobResolved(jobId, workerWon);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    function getJob(uint256 jobId) external view returns (Job memory) {
        return _requireJob(jobId);
    }

    function getResultCID(uint256 jobId) external view returns (bytes32) {
        return _resultCIDs[jobId];
    }

    function jobCount() external view returns (uint256) {
        return _jobCount;
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _requireJob(uint256 jobId) internal view returns (Job storage job) {
        job = _jobs[jobId];
        if (job.requester == address(0)) revert JobNotFound(jobId);
    }

    function _requireState(uint256 jobId, Job storage job, JobState required) internal view {
        if (job.state != required) revert InvalidState(jobId, job.state, required);
    }
}
