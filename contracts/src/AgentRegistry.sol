// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";

/// @title AgentRegistry
/// @notice On-chain capability marketplace. Agents register machine-readable profiles
///         so requesters can discover and filter them by task type and role.
contract AgentRegistry is IAgentRegistry {
    mapping(address => AgentProfile) private _profiles;
    mapping(address => bool) private _registered;

    address[] private _agentList;

    // -------------------------------------------------------------------------
    // Registration
    // -------------------------------------------------------------------------

    /// @notice Register a new agent profile.
    function registerAgent(AgentProfile calldata profile) external {
        if (_registered[msg.sender]) revert AgentAlreadyRegistered(msg.sender);
        _validateProfile(profile);

        _profiles[msg.sender] = AgentProfile({
            capabilitiesCID: profile.capabilitiesCID,
            taskTypes: profile.taskTypes,
            pricePerJob: profile.pricePerJob,
            maxLatencySeconds: profile.maxLatencySeconds,
            role: profile.role,
            active: true,
            registeredAt: block.timestamp
        });

        _registered[msg.sender] = true;
        _agentList.push(msg.sender);

        emit AgentRegistered(msg.sender, profile.role);
    }

    /// @notice Update an existing agent profile.
    function updateProfile(AgentProfile calldata profile) external {
        if (!_registered[msg.sender]) revert AgentNotFound(msg.sender);
        _validateProfile(profile);

        AgentProfile storage existing = _profiles[msg.sender];
        existing.capabilitiesCID = profile.capabilitiesCID;
        existing.taskTypes = profile.taskTypes;
        existing.pricePerJob = profile.pricePerJob;
        existing.maxLatencySeconds = profile.maxLatencySeconds;
        existing.role = profile.role;

        emit AgentUpdated(msg.sender);
    }

    /// @notice Deactivate an agent (soft-delete, preserves history).
    function deactivateAgent() external {
        if (!_registered[msg.sender]) revert AgentNotFound(msg.sender);
        _profiles[msg.sender].active = false;
        emit AgentDeactivated(msg.sender);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    function getProfile(address agent) external view returns (AgentProfile memory) {
        if (!_registered[agent]) revert AgentNotFound(agent);
        return _profiles[agent];
    }

    function isActive(address agent) external view returns (bool) {
        return _registered[agent] && _profiles[agent].active;
    }

    function hasRole(address agent, AgentRole role) external view returns (bool) {
        if (!_registered[agent] || !_profiles[agent].active) return false;
        AgentRole agentRole = _profiles[agent].role;
        if (agentRole == AgentRole.BOTH) return true;
        return agentRole == role;
    }

    /// @notice Returns the total number of registered agents.
    function agentCount() external view returns (uint256) {
        return _agentList.length;
    }

    /// @notice Returns a page of agent addresses for off-chain indexing.
    function getAgentPage(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory agents)
    {
        uint256 total = _agentList.length;
        if (offset >= total) return new address[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        agents = new address[](end - offset);
        for (uint256 i = 0; i < agents.length; i++) {
            agents[i] = _agentList[offset + i];
        }
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    function _validateProfile(AgentProfile calldata profile) internal pure {
        if (profile.capabilitiesCID == bytes32(0)) revert InvalidProfile();
        if (profile.taskTypes.length == 0) revert InvalidProfile();
        if (profile.maxLatencySeconds == 0) revert InvalidProfile();
    }
}
