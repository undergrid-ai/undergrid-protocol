// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReputationSystem} from "../src/ReputationSystem.sol";
import {IReputationSystem} from "../src/interfaces/IReputationSystem.sol";

contract ReputationSystemTest is Test {
    ReputationSystem internal rep;
    address internal authorizedCaller = makeAddr("authorized");
    address internal agent = makeAddr("agent");

    function setUp() public {
        rep = new ReputationSystem();
        rep.setAuthorized(authorizedCaller, true);
    }

    function test_newAgentGetsNeutralScore() public view {
        assertEq(rep.getScore(agent), 500);
    }

    function test_recordJobCompleted_updatesStats() public {
        vm.prank(authorizedCaller);
        rep.recordJobCompleted(agent, 30 minutes);

        IReputationSystem.AgentStats memory stats = rep.getStats(agent);
        assertEq(stats.totalJobs, 1);
        assertEq(stats.completedJobs, 1);
        assertEq(stats.cumulativeLatencySeconds, 30 minutes);
    }

    function test_recordJobFailed_updatesStats() public {
        vm.prank(authorizedCaller);
        rep.recordJobFailed(agent);

        IReputationSystem.AgentStats memory stats = rep.getStats(agent);
        assertEq(stats.totalJobs, 1);
        assertEq(stats.completedJobs, 0);
    }

    function test_scoreDegradesOnFailure() public {
        vm.startPrank(authorizedCaller);
        rep.recordJobCompleted(agent, 1 hours);
        uint256 scoreAfterSuccess = rep.getScore(agent);

        rep.recordJobFailed(agent);
        uint256 scoreAfterFailure = rep.getScore(agent);
        vm.stopPrank();

        assertGt(scoreAfterSuccess, scoreAfterFailure);
    }

    function test_disputeLostReducesScore() public {
        vm.startPrank(authorizedCaller);
        rep.recordJobCompleted(agent, 1 hours);
        uint256 before = rep.getScore(agent);
        rep.recordDisputeLost(agent);
        uint256 after_ = rep.getScore(agent);
        vm.stopPrank();

        assertGt(before, after_);
    }

    function test_verificationAccuracyAffectsScore() public {
        vm.startPrank(authorizedCaller);
        rep.recordVerificationResult(agent, true);
        rep.recordVerificationResult(agent, true);
        uint256 highScore = rep.getScore(agent);

        address badVerifier = makeAddr("badVerifier");
        rep.recordVerificationResult(badVerifier, false);
        rep.recordVerificationResult(badVerifier, false);
        uint256 lowScore = rep.getScore(badVerifier);
        vm.stopPrank();

        assertGt(highScore, lowScore);
    }

    function test_revertsUnauthorized() public {
        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IReputationSystem.NotAuthorized.selector, agent));
        rep.recordJobCompleted(agent, 1 hours);
    }

    function test_scoreMaximum() public {
        vm.startPrank(authorizedCaller);
        for (uint256 i = 0; i < 10; i++) {
            rep.recordJobCompleted(agent, 30 minutes);
            rep.recordVerificationResult(agent, true);
        }
        vm.stopPrank();
        assertLe(rep.getScore(agent), 1000);
    }
}
