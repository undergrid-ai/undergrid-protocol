// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ProtocolHelpers} from "./Helpers.sol";
import {IJobRegistry} from "../src/interfaces/IJobRegistry.sol";

contract JobRegistryTest is ProtocolHelpers {
    // -------------------------------------------------------------------------
    // createJob
    // -------------------------------------------------------------------------

    function test_createJob_success() public {
        uint256 requesterBefore = requester.balance;

        vm.prank(requester);
        uint256 jobId = jobRegistry.createJob{value: JOB_PAYMENT}(_defaultJobSpec());

        assertEq(jobId, 1);
        assertEq(jobRegistry.jobCount(), 1);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(job.requester, requester);
        assertEq(job.payment, JOB_PAYMENT);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.OPEN));
        assertEq(escrow.getLockedAmount(jobId), JOB_PAYMENT);
        assertEq(requester.balance, requesterBefore - JOB_PAYMENT);
    }

    function test_createJob_refundsOverpayment() public {
        uint256 overpayment = JOB_PAYMENT + 0.5 ether;
        uint256 requesterBefore = requester.balance;

        vm.prank(requester);
        jobRegistry.createJob{value: overpayment}(_defaultJobSpec());

        assertEq(requester.balance, requesterBefore - JOB_PAYMENT);
    }

    function test_createJob_revertsZeroPayment() public {
        IJobRegistry.JobSpec memory spec = _defaultJobSpec();
        spec.payment = 0;

        vm.prank(requester);
        vm.expectRevert(abi.encodeWithSelector(IJobRegistry.InsufficientPayment.selector, 1, 0));
        jobRegistry.createJob{value: 0}(spec);
    }

    function test_createJob_revertsInsufficientMsgValue() public {
        vm.prank(requester);
        vm.expectRevert(
            abi.encodeWithSelector(IJobRegistry.InsufficientPayment.selector, JOB_PAYMENT, JOB_PAYMENT / 2)
        );
        jobRegistry.createJob{value: JOB_PAYMENT / 2}(_defaultJobSpec());
    }

    function test_createJob_revertsDeadlineInPast() public {
        IJobRegistry.JobSpec memory spec = _defaultJobSpec();
        spec.bidDeadline = block.timestamp - 1;

        vm.prank(requester);
        vm.expectRevert(IJobRegistry.InvalidBidDeadline.selector);
        jobRegistry.createJob{value: JOB_PAYMENT}(spec);
    }

    function test_createJob_revertsShortChallengeWindow() public {
        IJobRegistry.JobSpec memory spec = _defaultJobSpec();
        spec.challengeWindow = 30 minutes; // below 1 hour minimum

        vm.prank(requester);
        vm.expectRevert(IJobRegistry.InvalidChallengeWindow.selector);
        jobRegistry.createJob{value: JOB_PAYMENT}(spec);
    }

    function test_createJob_emitsEvent() public {
        vm.prank(requester);
        vm.expectEmit(true, true, false, true);
        emit IJobRegistry.JobCreated(1, requester, JOB_PAYMENT);
        jobRegistry.createJob{value: JOB_PAYMENT}(_defaultJobSpec());
    }

    // -------------------------------------------------------------------------
    // cancelJob
    // -------------------------------------------------------------------------

    function test_cancelJob_success() public {
        uint256 jobId = _createJob();
        uint256 requesterBefore = requester.balance;

        vm.prank(requester);
        jobRegistry.cancelJob(jobId);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.CANCELLED));
        assertEq(requester.balance, requesterBefore + JOB_PAYMENT);
    }

    function test_cancelJob_revertsNotRequester() public {
        uint256 jobId = _createJob();

        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(IJobRegistry.NotRequester.selector, jobId, worker));
        jobRegistry.cancelJob(jobId);
    }

    function test_cancelJob_revertsWrongState() public {
        uint256 jobId = _createAndAcceptJob();

        vm.prank(requester);
        vm.expectRevert(
            abi.encodeWithSelector(
                IJobRegistry.InvalidState.selector, jobId, IJobRegistry.JobState.ACCEPTED, IJobRegistry.JobState.OPEN
            )
        );
        jobRegistry.cancelJob(jobId);
    }

    // -------------------------------------------------------------------------
    // acceptJob
    // -------------------------------------------------------------------------

    function test_acceptJob_success() public {
        uint256 jobId = _createJob();

        vm.prank(worker);
        jobRegistry.acceptJob(jobId, verifier);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(job.worker, worker);
        assertEq(job.verifier, verifier);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.ACCEPTED));
    }

    function test_acceptJob_revertsAfterBidDeadline() public {
        uint256 jobId = _createJob();
        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);

        vm.warp(job.bidDeadline + 1);

        vm.prank(worker);
        vm.expectRevert(abi.encodeWithSelector(IJobRegistry.BidDeadlinePassed.selector, jobId));
        jobRegistry.acceptJob(jobId, verifier);
    }

    function test_acceptJob_revertsInsufficientWorkerStake() public {
        address poorWorker = makeAddr("poorWorker");
        vm.deal(poorWorker, 10 ether);

        uint256 jobId = _createJob();

        vm.prank(poorWorker);
        vm.expectRevert(); // InsufficientPayment
        jobRegistry.acceptJob(jobId, verifier);
    }

    function test_acceptJob_revertsWrongState() public {
        uint256 jobId = _createAndAcceptJob();

        vm.prank(worker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IJobRegistry.InvalidState.selector,
                jobId,
                IJobRegistry.JobState.ACCEPTED,
                IJobRegistry.JobState.OPEN
            )
        );
        jobRegistry.acceptJob(jobId, verifier);
    }

    // -------------------------------------------------------------------------
    // submitResult
    // -------------------------------------------------------------------------

    function test_submitResult_success() public {
        uint256 jobId = _createAndAcceptJob();

        vm.prank(worker);
        jobRegistry.submitResult(jobId, RESULT_CID);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.SUBMITTED));
        assertEq(jobRegistry.getResultCID(jobId), RESULT_CID);
    }

    function test_submitResult_revertsNotWorker() public {
        uint256 jobId = _createAndAcceptJob();

        vm.prank(requester);
        vm.expectRevert(abi.encodeWithSelector(IJobRegistry.NotWorker.selector, jobId, requester));
        jobRegistry.submitResult(jobId, RESULT_CID);
    }

    // -------------------------------------------------------------------------
    // attestVerification
    // -------------------------------------------------------------------------

    function test_attestVerification_success() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(verifier);
        jobRegistry.attestVerification(jobId, true);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.VERIFIED));
    }

    function test_attestVerification_failureTriggersDispute() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(verifier);
        jobRegistry.attestVerification(jobId, false);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.DISPUTED));
    }

    function test_attestVerification_revertsNotVerifier() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(requester);
        vm.expectRevert(abi.encodeWithSelector(IJobRegistry.NotVerifier.selector, jobId, requester));
        jobRegistry.attestVerification(jobId, true);
    }

    // -------------------------------------------------------------------------
    // settleJob
    // -------------------------------------------------------------------------

    function test_settleJob_success() public {
        uint256 jobId = _createAcceptSubmitVerify();
        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);

        // Fast-forward past challenge window
        vm.warp(job.submittedAt + job.challengeWindow + 1);

        uint256 workerBefore = worker.balance;
        uint256 verifierBefore = verifier.balance;
        uint256 feeBefore = feeRecipient.balance;

        jobRegistry.settleJob(jobId);

        uint256 protocolFee = (JOB_PAYMENT * 50) / 10_000; // 0.5% of total locked
        uint256 workerNet = JOB_PAYMENT - VERIFIER_FEE - protocolFee;

        assertEq(feeRecipient.balance, feeBefore + protocolFee, "fee mismatch");
        assertEq(verifier.balance, verifierBefore + VERIFIER_FEE, "verifier fee mismatch");
        assertEq(worker.balance, workerBefore + workerNet, "worker amount mismatch");

        IJobRegistry.Job memory settled = jobRegistry.getJob(jobId);
        assertEq(uint8(settled.state), uint8(IJobRegistry.JobState.SETTLED));
    }

    function test_settleJob_revertsDuringChallengeWindow() public {
        uint256 jobId = _createAcceptSubmitVerify();

        vm.expectRevert(abi.encodeWithSelector(IJobRegistry.ChallengeWindowActive.selector, jobId));
        jobRegistry.settleJob(jobId);
    }

    function test_settleJob_updatesReputation() public {
        uint256 jobId = _createAcceptSubmitVerify();
        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);

        vm.warp(job.submittedAt + job.challengeWindow + 1);
        jobRegistry.settleJob(jobId);

        assertEq(reputation.getStats(worker).completedJobs, 1);
        assertEq(reputation.getStats(worker).totalJobs, 1);
    }

    function test_settleJob_revertsWrongState() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.expectRevert(
            abi.encodeWithSelector(
                IJobRegistry.InvalidState.selector,
                jobId,
                IJobRegistry.JobState.SUBMITTED,
                IJobRegistry.JobState.VERIFIED
            )
        );
        jobRegistry.settleJob(jobId);
    }

    // -------------------------------------------------------------------------
    // Full happy path
    // -------------------------------------------------------------------------

    function test_fullHappyPath() public {
        // 1. Create job
        uint256 jobId = _createJob();
        assertEq(uint8(jobRegistry.getJob(jobId).state), uint8(IJobRegistry.JobState.OPEN));

        // 2. Accept
        vm.prank(worker);
        jobRegistry.acceptJob(jobId, verifier);
        assertEq(uint8(jobRegistry.getJob(jobId).state), uint8(IJobRegistry.JobState.ACCEPTED));

        // 3. Submit
        vm.prank(worker);
        jobRegistry.submitResult(jobId, RESULT_CID);
        assertEq(uint8(jobRegistry.getJob(jobId).state), uint8(IJobRegistry.JobState.SUBMITTED));

        // 4. Verify
        vm.prank(verifier);
        jobRegistry.attestVerification(jobId, true);
        assertEq(uint8(jobRegistry.getJob(jobId).state), uint8(IJobRegistry.JobState.VERIFIED));

        // 5. Settle
        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        vm.warp(job.submittedAt + job.challengeWindow + 1);
        jobRegistry.settleJob(jobId);
        assertEq(uint8(jobRegistry.getJob(jobId).state), uint8(IJobRegistry.JobState.SETTLED));

        // Verify balances
        assertGt(worker.balance, 10 ether - WORKER_STAKE); // worker received payment
    }
}
