// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IJobRegistry} from "./IJobRegistry.sol";

/// @title IDisputeResolver
/// @notice Interface for challenge, multi-agent consensus, and arbitration
interface IDisputeResolver {
    enum DisputeState {
        NONE,
        CHALLENGED,
        VOTING, // multi-agent consensus in progress
        AWAITING_ARBITRATION,
        RESOLVED
    }

    struct Dispute {
        uint256 jobId;
        address challenger;
        DisputeState state;
        uint256 votesFor; // votes that worker was correct
        uint256 votesAgainst; // votes that worker was wrong
        uint256 deadline; // voting or arbitration deadline
        bool workerWon;
        bool resolved;
    }

    event DisputeRaised(uint256 indexed jobId, address indexed challenger);
    event VoteCast(uint256 indexed jobId, address indexed voter, bool supportsWorker);
    event DisputeResolved(uint256 indexed jobId, bool workerWon);
    event ArbitrationRequested(uint256 indexed jobId);

    error NoActiveDispute(uint256 jobId);
    error DisputeAlreadyExists(uint256 jobId);
    error ChallengeWindowExpired(uint256 jobId);
    error AlreadyVoted(uint256 jobId, address voter);
    error NotEligibleVoter(address caller);
    error VotingDeadlinePassed(uint256 jobId);
    error NotAuthorized(address caller);

    function raiseDispute(uint256 jobId) external;

    function castVote(uint256 jobId, bool supportsWorker) external;

    function resolveDispute(uint256 jobId) external;

    function requestArbitration(uint256 jobId) external;

    function applyArbitrationOutcome(uint256 jobId, bool workerWon) external;

    function getDispute(uint256 jobId) external view returns (Dispute memory);
}
