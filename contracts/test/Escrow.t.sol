// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";
import {IEscrow} from "../src/interfaces/IEscrow.sol";

contract EscrowTest is Test {
    Escrow internal escrow;
    address internal registry = makeAddr("registry");
    address internal requester = makeAddr("requester");
    address internal worker = makeAddr("worker");
    address internal verifierAddr = makeAddr("verifier");

    uint256 constant JOB_ID = 1;
    uint256 constant PAYMENT = 1 ether;
    uint256 constant VFEE = 0.1 ether;

    function setUp() public {
        escrow = new Escrow(registry);
        vm.deal(registry, 100 ether);
        vm.deal(requester, 100 ether);
    }

    function test_lockPayment() public {
        vm.prank(registry);
        escrow.lockPayment{value: PAYMENT}(JOB_ID, requester, VFEE);

        assertEq(escrow.getLockedAmount(JOB_ID), PAYMENT);
        assertEq(escrow.getVerifierFee(JOB_ID), VFEE);
    }

    function test_lockPayment_revertsNonRegistry() public {
        vm.prank(requester);
        vm.expectRevert(IEscrow.NotJobRegistry.selector);
        escrow.lockPayment{value: PAYMENT}(JOB_ID, requester, VFEE);
    }

    function test_lockPayment_revertsAlreadyLocked() public {
        vm.startPrank(registry);
        escrow.lockPayment{value: PAYMENT}(JOB_ID, requester, VFEE);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.AlreadyLocked.selector, JOB_ID));
        escrow.lockPayment{value: PAYMENT}(JOB_ID, requester, VFEE);
        vm.stopPrank();
    }

    function test_releasePayment() public {
        vm.prank(registry);
        escrow.lockPayment{value: PAYMENT}(JOB_ID, requester, VFEE);

        uint256 workerBefore = worker.balance;
        uint256 verifierBefore = verifierAddr.balance;

        address feeAddr = makeAddr("feeAddr");
        uint256 protocolFeeBps = 50; // 0.5%
        uint256 protocolFee = (PAYMENT * protocolFeeBps) / 10_000;

        vm.prank(registry);
        escrow.releasePayment(JOB_ID, worker, verifierAddr, feeAddr, protocolFeeBps);

        assertEq(verifierAddr.balance, verifierBefore + VFEE);
        assertEq(worker.balance, workerBefore + (PAYMENT - VFEE - protocolFee));
        assertEq(escrow.getLockedAmount(JOB_ID), PAYMENT); // raw value remains, locked=false
    }

    function test_releasePayment_revertsNotLocked() public {
        vm.prank(registry);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.NotLocked.selector, JOB_ID));
        escrow.releasePayment(JOB_ID, worker, verifierAddr, address(0), 0);
    }

    function test_refundPayment() public {
        vm.prank(registry);
        escrow.lockPayment{value: PAYMENT}(JOB_ID, requester, VFEE);

        uint256 before = requester.balance;

        vm.prank(registry);
        escrow.refundPayment(JOB_ID, requester);

        assertEq(requester.balance, before + PAYMENT);
    }

    function test_refundPayment_revertsNotLocked() public {
        vm.prank(registry);
        vm.expectRevert(abi.encodeWithSelector(IEscrow.NotLocked.selector, JOB_ID));
        escrow.refundPayment(JOB_ID, requester);
    }
}
