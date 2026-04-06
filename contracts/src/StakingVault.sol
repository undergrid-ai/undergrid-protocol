// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStakingVault} from "./interfaces/IStakingVault.sol";

/// @title StakingVault
/// @notice Manages agent collateral. Agents must maintain stake to participate.
///         Authorized contracts (JobRegistry, DisputeResolver) can slash stakes.
///         Unstaking uses a cooldown to prevent stake-and-flee attacks.
contract StakingVault is IStakingVault {
    uint256 public constant UNSTAKE_COOLDOWN = 3 days;

    struct StakeRecord {
        uint256 amount;
        uint256 pendingUnstake;
        uint256 unstakeAvailableAt;
    }

    mapping(address => StakeRecord) private _stakes;
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
    // Agent staking
    // -------------------------------------------------------------------------

    /// @notice Stake ETH to become eligible as a worker or verifier.
    function stake() external payable {
        if (msg.value == 0) revert ZeroAmount();
        _stakes[msg.sender].amount += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    /// @notice Begin unstake process. Funds enter cooldown.
    function initiateUnstake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        StakeRecord storage record = _stakes[msg.sender];
        if (record.amount < amount) {
            revert InsufficientStake(msg.sender, amount, record.amount);
        }

        record.amount -= amount;
        record.pendingUnstake += amount;
        record.unstakeAvailableAt = block.timestamp + UNSTAKE_COOLDOWN;
    }

    /// @notice Finalize unstake after cooldown elapses.
    function finalizeUnstake() external {
        StakeRecord storage record = _stakes[msg.sender];
        if (block.timestamp < record.unstakeAvailableAt) {
            revert CooldownActive(msg.sender, record.unstakeAvailableAt);
        }

        uint256 amount = record.pendingUnstake;
        if (amount == 0) revert ZeroAmount();
        record.pendingUnstake = 0;

        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    // -------------------------------------------------------------------------
    // Authorized: slashing
    // -------------------------------------------------------------------------

    /// @notice Slash an agent's stake. Slashed funds go to a beneficiary (e.g. challenger).
    function slash(address agent, uint256 amount, address beneficiary) external onlyAuthorized {
        StakeRecord storage record = _stakes[agent];
        if (record.amount < amount) {
            revert SlashExceedsStake(agent, amount, record.amount);
        }

        record.amount -= amount;

        (bool ok,) = beneficiary.call{value: amount}("");
        require(ok, "Slash transfer failed");

        emit Slashed(agent, amount, beneficiary);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    function getStake(address agent) external view returns (uint256) {
        return _stakes[agent].amount;
    }

    function meetsMinimum(address agent, uint256 minimum) external view returns (bool) {
        return _stakes[agent].amount >= minimum;
    }

    function getUnstakeCooldown() external pure returns (uint256) {
        return UNSTAKE_COOLDOWN;
    }

    function getPendingUnstake(address agent) external view returns (uint256 amount, uint256 availableAt) {
        StakeRecord storage record = _stakes[agent];
        return (record.pendingUnstake, record.unstakeAvailableAt);
    }
}
