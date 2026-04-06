// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IJobRegistry
/// @notice Interface for the core job lifecycle state machine
interface IJobRegistry {
    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------

    enum JobState {
        OPEN, // accepting bids
        ACCEPTED, // worker assigned
        SUBMITTED, // result posted, in challenge window
        VERIFIED, // verifier attested success
        SETTLED, // payment released
        DISPUTED, // challenge raised
        RESOLVED, // dispute outcome applied
        CANCELLED // requester cancelled before acceptance

    }

    enum DisputeMechanism {
        MULTI_AGENT_CONSENSUS, // ≥ 3 independent verifiers vote
        HUMAN_ARBITRATION, // escalate to off-chain oracle
        OPTIMISTIC // no verifier needed, challenge window only

    }

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Job {
        bytes32 descriptionCID; // IPFS CID of task specification
        bytes32 inputCID; // IPFS CID of input data
        bytes32 outputSchemaCID; // IPFS CID of expected output schema
        bytes32 successCriteriaCID; // IPFS CID of success rubric
        uint256 payment; // total payment in wei
        uint256 verifierFee; // portion reserved for verifier(s)
        uint256 bidDeadline; // timestamp: bids no longer accepted after this
        uint256 challengeWindow; // seconds after submission before settlement
        address requester;
        address worker;
        address verifier;
        DisputeMechanism disputeType;
        JobState state;
        uint256 createdAt;
        uint256 acceptedAt;
        uint256 submittedAt;
    }

    struct JobSpec {
        bytes32 descriptionCID;
        bytes32 inputCID;
        bytes32 outputSchemaCID;
        bytes32 successCriteriaCID;
        uint256 payment;
        uint256 verifierFee;
        uint256 bidDeadline;
        uint256 challengeWindow;
        DisputeMechanism disputeType;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event JobCreated(uint256 indexed jobId, address indexed requester, uint256 payment);
    event JobAccepted(uint256 indexed jobId, address indexed worker);
    event ResultSubmitted(uint256 indexed jobId, address indexed worker, bytes32 resultCID);
    event JobVerified(uint256 indexed jobId, address indexed verifier);
    event JobSettled(uint256 indexed jobId, address indexed worker, uint256 payment);
    event JobDisputed(uint256 indexed jobId, address indexed challenger);
    event JobResolved(uint256 indexed jobId, bool workerWon);
    event JobCancelled(uint256 indexed jobId);
    event VerifierAssigned(uint256 indexed jobId, address indexed verifier);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error JobNotFound(uint256 jobId);
    error InvalidState(uint256 jobId, JobState current, JobState required);
    error BidDeadlinePassed(uint256 jobId);
    error ChallengeWindowActive(uint256 jobId);
    error NotRequester(uint256 jobId, address caller);
    error NotWorker(uint256 jobId, address caller);
    error NotVerifier(uint256 jobId, address caller);
    error InsufficientPayment(uint256 required, uint256 provided);
    error ZeroAddress();
    error InvalidBidDeadline();
    error InvalidChallengeWindow();

    // -------------------------------------------------------------------------
    // Functions
    // -------------------------------------------------------------------------

    function createJob(JobSpec calldata spec) external payable returns (uint256 jobId);

    function acceptJob(uint256 jobId, address verifier) external;

    function submitResult(uint256 jobId, bytes32 resultCID) external;

    function attestVerification(uint256 jobId, bool success) external;

    function settleJob(uint256 jobId) external;

    function cancelJob(uint256 jobId) external;

    function getJob(uint256 jobId) external view returns (Job memory);

    function getResultCID(uint256 jobId) external view returns (bytes32);

    function jobCount() external view returns (uint256);
}
