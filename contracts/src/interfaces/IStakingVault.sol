// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IStakingVault
/// @notice Interface for agent collateral staking and slashing
interface IStakingVault {
    event Staked(address indexed agent, uint256 amount);
    event Unstaked(address indexed agent, uint256 amount);
    event Slashed(address indexed agent, uint256 amount, address indexed beneficiary);

    error InsufficientStake(address agent, uint256 required, uint256 actual);
    error SlashExceedsStake(address agent, uint256 slash, uint256 stake);
    error NotAuthorized(address caller);
    error CooldownActive(address agent, uint256 availableAt);
    error ZeroAmount();

    function stake() external payable;

    function initiateUnstake(uint256 amount) external;

    function finalizeUnstake() external;

    function slash(address agent, uint256 amount, address beneficiary) external;

    function getStake(address agent) external view returns (uint256);

    function meetsMinimum(address agent, uint256 minimum) external view returns (bool);

    function getUnstakeCooldown() external view returns (uint256);
}
