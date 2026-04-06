// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEscrow} from "./interfaces/IEscrow.sol";

/// @title Escrow
/// @notice Holds job payments and releases them based on outcomes reported by JobRegistry.
///         Only the authorized JobRegistry address can trigger payment operations.
contract Escrow is IEscrow {
    struct EscrowRecord {
        uint256 totalAmount;
        uint256 verifierFee;
        address requester;
        bool locked;
    }

    address public immutable jobRegistry;

    mapping(uint256 => EscrowRecord) private _records;

    modifier onlyJobRegistry() {
        if (msg.sender != jobRegistry) revert NotJobRegistry();
        _;
    }

    constructor(address _jobRegistry) {
        require(_jobRegistry != address(0), "Zero address");
        jobRegistry = _jobRegistry;
    }

    // -------------------------------------------------------------------------
    // JobRegistry-only functions
    // -------------------------------------------------------------------------

    /// @notice Lock payment for a job. Called during createJob.
    function lockPayment(uint256 jobId, address requester, uint256 verifierFee)
        external
        payable
        onlyJobRegistry
    {
        if (_records[jobId].locked) revert AlreadyLocked(jobId);

        _records[jobId] = EscrowRecord({
            totalAmount: msg.value,
            verifierFee: verifierFee,
            requester: requester,
            locked: true
        });

        emit PaymentLocked(jobId, msg.value);
    }

    /// @notice Release payment: verifier fee → verifier, protocol fee → feeRecipient, remainder → worker.
    function releasePayment(
        uint256 jobId,
        address worker,
        address verifier,
        address feeRecipient,
        uint256 protocolFeeBps
    ) external onlyJobRegistry {
        EscrowRecord storage record = _records[jobId];
        if (!record.locked) revert NotLocked(jobId);

        uint256 total = record.totalAmount;
        uint256 vFee = record.verifierFee;
        uint256 protocolFee = (total * protocolFeeBps) / 10_000;
        uint256 workerAmount = total - vFee - protocolFee;
        record.locked = false;

        if (vFee > 0 && verifier != address(0)) {
            (bool ok1,) = verifier.call{value: vFee}("");
            require(ok1, "Verifier transfer failed");
            emit VerifierFeePaid(jobId, verifier, vFee);
        }

        if (protocolFee > 0 && feeRecipient != address(0)) {
            (bool ok2,) = feeRecipient.call{value: protocolFee}("");
            require(ok2, "Fee transfer failed");
        }

        (bool ok3,) = worker.call{value: workerAmount}("");
        require(ok3, "Worker transfer failed");

        emit PaymentReleased(jobId, worker, workerAmount);
    }

    /// @notice Refund payment to requester. Used on cancel or failed dispute.
    function refundPayment(uint256 jobId, address requester) external onlyJobRegistry {
        EscrowRecord storage record = _records[jobId];
        if (!record.locked) revert NotLocked(jobId);

        uint256 amount = record.totalAmount;
        record.locked = false;

        (bool ok,) = requester.call{value: amount}("");
        require(ok, "Refund transfer failed");

        emit PaymentRefunded(jobId, requester, amount);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    function getLockedAmount(uint256 jobId) external view returns (uint256) {
        return _records[jobId].totalAmount;
    }

    function getVerifierFee(uint256 jobId) external view returns (uint256) {
        return _records[jobId].verifierFee;
    }
}
