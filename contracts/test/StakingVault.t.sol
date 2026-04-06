// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StakingVault} from "../src/StakingVault.sol";
import {IStakingVault} from "../src/interfaces/IStakingVault.sol";

contract StakingVaultTest is Test {
    StakingVault internal vault;
    address internal agent = makeAddr("agent");
    address internal slasher = makeAddr("slasher");
    address internal beneficiary = makeAddr("beneficiary");

    uint256 constant STAKE_AMOUNT = 1 ether;

    function setUp() public {
        vault = new StakingVault();
        vault.setAuthorized(slasher, true);
        vm.deal(agent, 10 ether);
        vm.deal(slasher, 1 ether);
    }

    function test_stake() public {
        vm.prank(agent);
        vault.stake{value: STAKE_AMOUNT}();
        assertEq(vault.getStake(agent), STAKE_AMOUNT);
    }

    function test_stake_revertsZeroAmount() public {
        vm.prank(agent);
        vm.expectRevert(IStakingVault.ZeroAmount.selector);
        vault.stake{value: 0}();
    }

    function test_stake_accumulates() public {
        vm.startPrank(agent);
        vault.stake{value: 0.5 ether}();
        vault.stake{value: 0.5 ether}();
        vm.stopPrank();
        assertEq(vault.getStake(agent), STAKE_AMOUNT);
    }

    function test_meetsMinimum() public {
        vm.prank(agent);
        vault.stake{value: STAKE_AMOUNT}();

        assertTrue(vault.meetsMinimum(agent, STAKE_AMOUNT));
        assertTrue(vault.meetsMinimum(agent, STAKE_AMOUNT - 1));
        assertFalse(vault.meetsMinimum(agent, STAKE_AMOUNT + 1));
    }

    function test_initiateAndFinalizeUnstake() public {
        vm.prank(agent);
        vault.stake{value: STAKE_AMOUNT}();

        vm.prank(agent);
        vault.initiateUnstake(STAKE_AMOUNT);

        assertEq(vault.getStake(agent), 0);
        (uint256 pending, uint256 availableAt) = vault.getPendingUnstake(agent);
        assertEq(pending, STAKE_AMOUNT);
        assertEq(availableAt, block.timestamp + vault.getUnstakeCooldown());

        // Cannot finalize yet
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(IStakingVault.CooldownActive.selector, agent, availableAt)
        );
        vault.finalizeUnstake();

        // Warp past cooldown
        vm.warp(availableAt + 1);
        uint256 before = agent.balance;
        vm.prank(agent);
        vault.finalizeUnstake();
        assertEq(agent.balance, before + STAKE_AMOUNT);
    }

    function test_slash() public {
        vm.prank(agent);
        vault.stake{value: STAKE_AMOUNT}();

        uint256 slashAmount = 0.3 ether;
        uint256 beneficiaryBefore = beneficiary.balance;

        vm.prank(slasher);
        vault.slash(agent, slashAmount, beneficiary);

        assertEq(vault.getStake(agent), STAKE_AMOUNT - slashAmount);
        assertEq(beneficiary.balance, beneficiaryBefore + slashAmount);
    }

    function test_slash_revertsExceedsStake() public {
        vm.prank(agent);
        vault.stake{value: STAKE_AMOUNT}();

        vm.prank(slasher);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStakingVault.SlashExceedsStake.selector, agent, STAKE_AMOUNT + 1 ether, STAKE_AMOUNT
            )
        );
        vault.slash(agent, STAKE_AMOUNT + 1 ether, beneficiary);
    }

    function test_slash_revertsUnauthorized() public {
        vm.prank(agent);
        vault.stake{value: STAKE_AMOUNT}();

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(IStakingVault.NotAuthorized.selector, agent));
        vault.slash(agent, 0.1 ether, beneficiary);
    }
}
