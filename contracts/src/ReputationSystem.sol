// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IReputationSystem} from "./interfaces/IReputationSystem.sol";

/// @title ReputationSystem
/// @notice Tracks per-agent performance statistics. Writable only by authorized
///         protocol contracts (JobRegistry, DisputeResolver).
///
/// Score formula (0-1000):
///   completion    = completedJobs / totalJobs                  * 400 pts
///   verification  = verificationsPassed / total verifications  * 300 pts (verifiers)
///   dispute       = 1 - (disputesLost / totalJobs)             * 200 pts
///   latency       = score based on avg latency vs 1h target     * 100 pts
contract ReputationSystem is IReputationSystem {
    uint256 private constant MAX_SCORE = 1000;
    uint256 private constant LATENCY_TARGET = 1 hours; // target latency for full latency score

    mapping(address => AgentStats) private _stats;
    mapping(address => bool) public authorized;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        if (!authorized[msg.sender]) revert NotAuthorized(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    function setAuthorized(address account, bool status) external onlyOwner {
        authorized[account] = status;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // -------------------------------------------------------------------------
    // Write functions (authorized callers only)
    // -------------------------------------------------------------------------

    function recordJobCompleted(address worker, uint256 latencySeconds) external onlyAuthorized {
        AgentStats storage stats = _stats[worker];
        stats.totalJobs += 1;
        stats.completedJobs += 1;
        stats.cumulativeLatencySeconds += latencySeconds;
        stats.lastUpdated = block.timestamp;
        emit StatsRecorded(worker, "jobCompleted");
        emit ScoreUpdated(worker, getScore(worker));
    }

    function recordJobFailed(address worker) external onlyAuthorized {
        AgentStats storage stats = _stats[worker];
        stats.totalJobs += 1;
        stats.lastUpdated = block.timestamp;
        emit StatsRecorded(worker, "jobFailed");
        emit ScoreUpdated(worker, getScore(worker));
    }

    function recordDisputeLost(address agent) external onlyAuthorized {
        _stats[agent].disputesLost += 1;
        _stats[agent].lastUpdated = block.timestamp;
        emit StatsRecorded(agent, "disputeLost");
        emit ScoreUpdated(agent, getScore(agent));
    }

    function recordVerificationResult(address verifier, bool correct) external onlyAuthorized {
        AgentStats storage stats = _stats[verifier];
        if (correct) {
            stats.verificationsPassed += 1;
        } else {
            stats.verificationsFailed += 1;
        }
        stats.lastUpdated = block.timestamp;
        emit StatsRecorded(verifier, correct ? "verificationPassed" : "verificationFailed");
        emit ScoreUpdated(verifier, getScore(verifier));
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    function getStats(address agent) external view returns (AgentStats memory) {
        return _stats[agent];
    }

    /// @notice Compute composite score (0-1000) for an agent.
    function getScore(address agent) public view returns (uint256) {
        AgentStats storage stats = _stats[agent];

        if (stats.totalJobs == 0 && stats.verificationsPassed == 0 && stats.verificationsFailed == 0) {
            return 500; // neutral starting score for new agents
        }

        uint256 score = 0;

        // Completion component (400 pts)
        if (stats.totalJobs > 0) {
            score += (stats.completedJobs * 400) / stats.totalJobs;
        } else {
            score += 400;
        }

        // Verification accuracy component (300 pts) — relevant for verifiers
        uint256 totalVerifications = stats.verificationsPassed + stats.verificationsFailed;
        if (totalVerifications > 0) {
            score += (stats.verificationsPassed * 300) / totalVerifications;
        } else {
            score += 300;
        }

        // Dispute loss component (200 pts)
        if (stats.totalJobs > 0) {
            uint256 disputeRate = (stats.disputesLost * 200) / stats.totalJobs;
            score += disputeRate > 200 ? 0 : (200 - disputeRate);
        } else {
            score += 200;
        }

        // Latency component (100 pts) — lower is better
        if (stats.completedJobs > 0) {
            uint256 avgLatency = stats.cumulativeLatencySeconds / stats.completedJobs;
            if (avgLatency <= LATENCY_TARGET) {
                score += 100;
            } else if (avgLatency <= LATENCY_TARGET * 10) {
                // Linear decay over 10x target
                score += 100 - (100 * (avgLatency - LATENCY_TARGET)) / (LATENCY_TARGET * 9);
            }
            // Beyond 10x target: 0 latency points
        } else {
            score += 100;
        }

        return score > MAX_SCORE ? MAX_SCORE : score;
    }
}
