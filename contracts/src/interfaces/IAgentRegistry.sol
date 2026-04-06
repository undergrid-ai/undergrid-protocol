// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAgentRegistry
/// @notice Interface for on-chain agent capability profiles
interface IAgentRegistry {
    enum AgentRole {
        WORKER,
        VERIFIER,
        BOTH
    }

    struct AgentProfile {
        bytes32 capabilitiesCID; // IPFS CID of machine-readable capability manifest
        string[] taskTypes; // e.g. ["summarization","classification","coding"]
        uint256 pricePerJob; // minimum price agent accepts (wei)
        uint256 maxLatencySeconds; // SLA latency commitment
        AgentRole role;
        bool active;
        uint256 registeredAt;
    }

    event AgentRegistered(address indexed agent, AgentRole role);
    event AgentUpdated(address indexed agent);
    event AgentDeactivated(address indexed agent);

    error AgentAlreadyRegistered(address agent);
    error AgentNotFound(address agent);
    error AgentNotActive(address agent);
    error InvalidProfile();

    function registerAgent(AgentProfile calldata profile) external;

    function updateProfile(AgentProfile calldata profile) external;

    function deactivateAgent() external;

    function getProfile(address agent) external view returns (AgentProfile memory);

    function isActive(address agent) external view returns (bool);

    function hasRole(address agent, AgentRole role) external view returns (bool);
}
