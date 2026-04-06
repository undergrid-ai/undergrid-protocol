// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title UnderGridErrors
/// @notice Shared protocol-level errors not tied to a specific contract
library UnderGridErrors {
    error Unauthorized(address caller, address expected);
    error DeadlineInPast(uint256 deadline, uint256 currentTime);
    error ZeroAmount();
    error ZeroAddress();
    error AlreadyInitialized();
}
