// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEscrow
/// @notice Interface for job payment locking and release
interface IEscrow {
    event PaymentLocked(uint256 indexed jobId, uint256 amount);
    event PaymentReleased(uint256 indexed jobId, address indexed recipient, uint256 amount);
    event PaymentRefunded(uint256 indexed jobId, address indexed requester, uint256 amount);
    event VerifierFeePaid(uint256 indexed jobId, address indexed verifier, uint256 fee);

    error NotJobRegistry();
    error AlreadyLocked(uint256 jobId);
    error NotLocked(uint256 jobId);
    error InsufficientBalance(uint256 jobId);

    function lockPayment(uint256 jobId, address requester, uint256 verifierFee) external payable;

    function releasePayment(
        uint256 jobId,
        address worker,
        address verifier,
        address feeRecipient,
        uint256 protocolFeeBps
    ) external;

    function refundPayment(uint256 jobId, address requester) external;

    function getLockedAmount(uint256 jobId) external view returns (uint256);

    function getVerifierFee(uint256 jobId) external view returns (uint256);
}
