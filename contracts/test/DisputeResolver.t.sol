// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProtocolHelpers} from "./Helpers.sol";
import {IJobRegistry} from "../src/interfaces/IJobRegistry.sol";
import {IDisputeResolver} from "../src/interfaces/IDisputeResolver.sol";

contract DisputeResolverTest is ProtocolHelpers {
    // -------------------------------------------------------------------------
    // raiseDispute
    // -------------------------------------------------------------------------

    function test_raiseDispute_success() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        IDisputeResolver.Dispute memory d = disputeResolver.getDispute(jobId);
        assertEq(d.challenger, challenger);
        assertEq(uint8(d.state), uint8(IDisputeResolver.DisputeState.VOTING));
    }

    function test_raiseDispute_revertsDoubleDispute() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        vm.prank(challenger);
        vm.expectRevert(abi.encodeWithSelector(IDisputeResolver.DisputeAlreadyExists.selector, jobId));
        disputeResolver.raiseDispute(jobId);
    }

    function test_raiseDispute_revertsWrongState() public {
        uint256 jobId = _createAndAcceptJob(); // ACCEPTED, not SUBMITTED

        vm.prank(challenger);
        vm.expectRevert(abi.encodeWithSelector(IDisputeResolver.ChallengeWindowExpired.selector, jobId));
        disputeResolver.raiseDispute(jobId);
    }

    function test_raiseDispute_revertsNoStake() public {
        address poorChallenger = makeAddr("poorChallenger");
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(poorChallenger);
        vm.expectRevert(); // insufficient challenger stake
        disputeResolver.raiseDispute(jobId);
    }

    // -------------------------------------------------------------------------
    // castVote + resolveDispute (worker wins)
    // -------------------------------------------------------------------------

    function test_dispute_workerWins_releasesPayment() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        // Stake voters
        vm.deal(voter1, 1 ether);
        vm.deal(voter2, 1 ether);
        vm.deal(voter3, 1 ether);
        vm.prank(voter1);
        stakingVault.stake{value: 0.01 ether}();
        vm.prank(voter2);
        stakingVault.stake{value: 0.01 ether}();
        vm.prank(voter3);
        stakingVault.stake{value: 0.01 ether}();

        // 3 votes for worker
        vm.prank(voter1);
        disputeResolver.castVote(jobId, true);
        vm.prank(voter2);
        disputeResolver.castVote(jobId, true);
        vm.prank(voter3);
        disputeResolver.castVote(jobId, true);

        uint256 workerBefore = worker.balance;

        // Warp past voting deadline
        vm.warp(block.timestamp + disputeResolver.VOTING_DURATION() + 1);
        disputeResolver.resolveDispute(jobId);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.RESOLVED));
        assertGt(worker.balance, workerBefore); // worker received payment
    }

    function test_dispute_workerLoses_refundsRequester() public {
        uint256 jobId = _createAcceptAndSubmit();
        uint256 requesterBefore = requester.balance;

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        // Stake voters
        vm.deal(voter1, 1 ether);
        vm.deal(voter2, 1 ether);
        vm.deal(voter3, 1 ether);
        vm.prank(voter1);
        stakingVault.stake{value: 0.01 ether}();
        vm.prank(voter2);
        stakingVault.stake{value: 0.01 ether}();
        vm.prank(voter3);
        stakingVault.stake{value: 0.01 ether}();

        // 3 votes against worker
        vm.prank(voter1);
        disputeResolver.castVote(jobId, false);
        vm.prank(voter2);
        disputeResolver.castVote(jobId, false);
        vm.prank(voter3);
        disputeResolver.castVote(jobId, false);

        vm.warp(block.timestamp + disputeResolver.VOTING_DURATION() + 1);
        disputeResolver.resolveDispute(jobId);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.RESOLVED));
        assertGt(requester.balance, requesterBefore); // requester was refunded
    }

    function test_dispute_insufficientVotes_escalatesToArbitration() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        // Only 2 votes — below MIN_VOTES_FOR_CONSENSUS of 3
        vm.deal(voter1, 1 ether);
        vm.deal(voter2, 1 ether);
        vm.prank(voter1);
        stakingVault.stake{value: 0.01 ether}();
        vm.prank(voter2);
        stakingVault.stake{value: 0.01 ether}();
        vm.prank(voter1);
        disputeResolver.castVote(jobId, true);
        vm.prank(voter2);
        disputeResolver.castVote(jobId, false);

        vm.warp(block.timestamp + disputeResolver.VOTING_DURATION() + 1);
        disputeResolver.resolveDispute(jobId);

        IDisputeResolver.Dispute memory d = disputeResolver.getDispute(jobId);
        assertEq(uint8(d.state), uint8(IDisputeResolver.DisputeState.AWAITING_ARBITRATION));
    }

    function test_arbitration_workerWins() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        // Insufficient votes → escalate
        vm.warp(block.timestamp + disputeResolver.VOTING_DURATION() + 1);
        disputeResolver.resolveDispute(jobId);

        uint256 workerBefore = worker.balance;
        vm.prank(arbitrator);
        disputeResolver.applyArbitrationOutcome(jobId, true);

        assertGt(worker.balance, workerBefore);
        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.RESOLVED));
    }

    function test_castVote_revertsAlreadyVoted() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        vm.deal(voter1, 1 ether);
        vm.prank(voter1);
        stakingVault.stake{value: 0.01 ether}();

        vm.prank(voter1);
        disputeResolver.castVote(jobId, true);

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(IDisputeResolver.AlreadyVoted.selector, jobId, voter1));
        disputeResolver.castVote(jobId, true);
    }

    function test_castVote_revertsNonVerifier() public {
        uint256 jobId = _createAcceptAndSubmit();

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        address randomAddr = makeAddr("random");
        vm.prank(randomAddr);
        vm.expectRevert(abi.encodeWithSelector(IDisputeResolver.NotEligibleVoter.selector, randomAddr));
        disputeResolver.castVote(jobId, true);
    }

    // -------------------------------------------------------------------------
    // Human arbitration path
    // -------------------------------------------------------------------------

    function test_humanArbitration_disputeType() public {
        // Create job with HUMAN_ARBITRATION dispute type
        IJobRegistry.JobSpec memory spec = _defaultJobSpec();
        spec.disputeType = IJobRegistry.DisputeMechanism.HUMAN_ARBITRATION;

        vm.prank(requester);
        uint256 jobId = jobRegistry.createJob{value: JOB_PAYMENT}(spec);

        vm.prank(worker);
        jobRegistry.acceptJob(jobId, verifier);

        vm.prank(worker);
        jobRegistry.submitResult(jobId, RESULT_CID);

        vm.prank(challenger);
        disputeResolver.raiseDispute(jobId);

        // Should go straight to AWAITING_ARBITRATION
        IDisputeResolver.Dispute memory d = disputeResolver.getDispute(jobId);
        assertEq(uint8(d.state), uint8(IDisputeResolver.DisputeState.AWAITING_ARBITRATION));

        vm.prank(arbitrator);
        disputeResolver.applyArbitrationOutcome(jobId, false);

        IJobRegistry.Job memory job = jobRegistry.getJob(jobId);
        assertEq(uint8(job.state), uint8(IJobRegistry.JobState.RESOLVED));
    }
}
