// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IReputationSystem
/// @notice Interface for tracking agent performance track records
interface IReputationSystem {
    struct AgentStats {
        uint256 totalJobs;
        uint256 completedJobs;
        uint256 disputesLost;
        uint256 verificationsPassed; // verifier metric: verified correctly
        uint256 verificationsFailed; // verifier metric: later overturned
        uint256 cumulativeLatencySeconds;
        uint256 lastUpdated;
    }

    event ScoreUpdated(address indexed agent, uint256 newScore);
    event StatsRecorded(address indexed agent, string metric);

    error NotAuthorized(address caller);
    error AgentNotFound(address agent);

    function recordJobCompleted(address worker, uint256 latencySeconds) external;

    function recordJobFailed(address worker) external;

    function recordDisputeLost(address agent) external;

    function recordVerificationResult(address verifier, bool correct) external;

    function getStats(address agent) external view returns (AgentStats memory);

    function getScore(address agent) external view returns (uint256);
}
