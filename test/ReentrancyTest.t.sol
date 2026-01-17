// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {SimpleBank} from "../src/SimpleBank.sol";
import {SecureBank} from "../src/SecureBank.sol";
import {Attacker} from "../src/Attacker.sol";
import {ReentrancyGuard} from "../src/utils/ReentrancyGuard.sol";

/// @title ReentrancyTest
/// @author Agustin Acosta
/// @notice Comprehensive unit and exploit testing for reentrancy attack and mitigation.
contract ReentrancyTest is Test {
    SimpleBank simpleBank;
    SecureBank secureBank;

    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");

    function setUp() public {
        simpleBank = new SimpleBank();
        secureBank = new SecureBank();

        // Fund actors with Ether
        vm.deal(ALICE, 50 ether);
        vm.deal(BOB, 50 ether);

        // Pre-fund the banks with 10 ETH from Alice to simulate existing deposits
        vm.prank(ALICE);
        simpleBank.deposit{value: 10 ether}();

        vm.prank(ALICE);
        secureBank.deposit{value: 10 ether}();
    }

    // ═════════════════════════════════════════════════════════════════════
    // EXPLOIT TESTS
    // ═════════════════════════════════════════════════════════════════════

    /// @notice Verify that a reentrancy attack successfully drains SimpleBank.
    function test_SimpleBank_Attack_Success() public {
        vm.startPrank(BOB);
        Attacker attacker = new Attacker(address(simpleBank));

        uint256 bankBalanceBefore = address(simpleBank).balance;

        // Execute the attack, depositing 1 ETH to trigger the exploit
        attacker.attack{value: 1 ether}();

        uint256 bankBalanceAfter = address(simpleBank).balance;
        uint256 attackerBalanceAfter = address(attacker).balance;

        assertEq(bankBalanceAfter, 0, "SimpleBank must be fully drained");
        assertEq(attackerBalanceAfter, bankBalanceBefore + 1 ether, "Attacker must hold all bank funds");

        // Bob withdraws the stolen funds from the attacker contract
        attacker.withdrawStolenFunds();
        assertEq(BOB.balance, 49 ether + bankBalanceBefore + 1 ether, "Bob should receive stolen funds");
        vm.stopPrank();
    }

    /// @notice Verify that the reentrancy attack is blocked on SecureBank.
    function test_RevertWhen_SecureBank_Attack_Fails() public {
        vm.startPrank(BOB);
        Attacker attacker = new Attacker(address(secureBank));

        // Reentrant call fails during interaction fallback, which reverts the parent call with WithdrawalFailed
        vm.expectRevert(SecureBank.WithdrawalFailed.selector);
        attacker.attack{value: 1 ether}();
        vm.stopPrank();
    }

    // ═════════════════════════════════════════════════════════════════════
    // EDGE CASES & COVERAGE TESTS
    // ═════════════════════════════════════════════════════════════════════

    /// @notice Verify normal deposit and withdrawal functionality on SimpleBank.
    function test_SimpleBank_NormalDepositAndWithdraw() public {
        vm.startPrank(BOB);
        simpleBank.deposit{value: 5 ether}();
        assertEq(simpleBank.userBalance(BOB), 5 ether);
        assertEq(simpleBank.totalBalance(), 15 ether);

        simpleBank.withdraw();
        assertEq(simpleBank.userBalance(BOB), 0);
        assertEq(simpleBank.totalBalance(), 10 ether);
        vm.stopPrank();
    }

    /// @notice Verify normal deposit and withdrawal functionality on SecureBank.
    function test_SecureBank_NormalDepositAndWithdraw() public {
        vm.startPrank(BOB);
        secureBank.deposit{value: 5 ether}();
        assertEq(secureBank.userBalance(BOB), 5 ether);
        assertEq(secureBank.totalBalance(), 15 ether);

        secureBank.withdraw();
        assertEq(secureBank.userBalance(BOB), 0);
        assertEq(secureBank.totalBalance(), 10 ether);
        vm.stopPrank();
    }

    /// @notice Verify deposit reverts if deposit value is below 1 ETH.
    function test_RevertWhen_DepositTooLow() public {
        vm.startPrank(BOB);
        vm.expectRevert(SimpleBank.DepositTooLow.selector);
        simpleBank.deposit{value: 0.5 ether}();

        vm.expectRevert(SecureBank.DepositTooLow.selector);
        secureBank.deposit{value: 0.5 ether}();
        vm.stopPrank();
    }

    /// @notice Verify withdrawal reverts if caller has no balance.
    function test_RevertWhen_WithdrawInsufficientBalance() public {
        vm.startPrank(BOB);
        vm.expectRevert(SimpleBank.InsufficientBalance.selector);
        simpleBank.withdraw();

        vm.expectRevert(SecureBank.InsufficientBalance.selector);
        secureBank.withdraw();
        vm.stopPrank();
    }

    /// @notice Verify withdrawal reverts if the bank has a zero balance.
    function test_RevertWhen_WithdrawBankEmpty() public {
        // SimpleBank case
        vm.prank(BOB);
        simpleBank.deposit{value: 1 ether}();
        vm.deal(address(simpleBank), 0);
        vm.prank(BOB);
        vm.expectRevert(SimpleBank.BankEmpty.selector);
        simpleBank.withdraw();

        // SecureBank case
        vm.prank(BOB);
        secureBank.deposit{value: 1 ether}();
        vm.deal(address(secureBank), 0);
        vm.prank(BOB);
        vm.expectRevert(SecureBank.BankEmpty.selector);
        secureBank.withdraw();
    }

    /// @notice Verify withdrawal reverts if the recipient call fails.
    function test_RevertWhen_WithdrawalFailed() public {
        // SimpleBank recipient failure
        RevertingRecipient simpleRecipient = new RevertingRecipient();
        vm.deal(address(simpleRecipient), 5 ether);
        
        vm.prank(address(simpleRecipient));
        simpleBank.deposit{value: 2 ether}();

        vm.prank(address(simpleRecipient));
        vm.expectRevert(SimpleBank.WithdrawalFailed.selector);
        simpleBank.withdraw();

        // SecureBank recipient failure
        RevertingRecipient secureRecipient = new RevertingRecipient();
        vm.deal(address(secureRecipient), 5 ether);
        
        vm.prank(address(secureRecipient));
        secureBank.deposit{value: 2 ether}();

        vm.prank(address(secureRecipient));
        vm.expectRevert(SecureBank.WithdrawalFailed.selector);
        secureBank.withdraw();
    }

    /// @notice Verify Attacker constructor reverts if zero address target is passed.
    function test_RevertWhen_Attacker_ZeroAddress() public {
        vm.expectRevert(Attacker.ZeroAddress.selector);
        new Attacker(address(0));
    }

    /// @notice Verify Attacker exploit reverts if value is below 1 ETH.
    function test_RevertWhen_Attacker_DepositTooLow() public {
        Attacker attacker = new Attacker(address(simpleBank));
        vm.expectRevert(Attacker.DepositTooLow.selector);
        attacker.attack{value: 0.5 ether}();
    }

    /// @notice Verify Attacker withdrawal of stolen funds reverts for unauthorized callers.
    function test_RevertWhen_Attacker_UnauthorizedWithdrawal() public {
        vm.startPrank(BOB);
        Attacker attacker = new Attacker(address(simpleBank));
        vm.stopPrank();

        vm.prank(ALICE);
        vm.expectRevert(Attacker.Unauthorized.selector);
        attacker.withdrawStolenFunds();
    }

    /// @notice Verify Attacker withdrawal of stolen funds reverts if the transfer to the owner fails.
    function test_RevertWhen_Attacker_TransferFailed() public {
        RevertingOwner revertingOwner = new RevertingOwner();
        vm.deal(address(revertingOwner), 10 ether);

        // Deploy attacker and execute attack as reverting owner
        vm.prank(address(revertingOwner));
        address attackerAddress = revertingOwner.deployAndAttack{value: 1 ether}(address(simpleBank));

        // Attempting to withdraw stolen funds must fail because the owner contract refuses Ether
        vm.prank(address(revertingOwner));
        vm.expectRevert(Attacker.TransferFailed.selector);
        revertingOwner.withdraw(attackerAddress);
    }
}

contract RevertingOwner {
    receive() external payable {
        revert("I refuse stolen funds");
    }

    function deployAndAttack(address _bank) external payable returns (address) {
        Attacker attacker = new Attacker(_bank);
        attacker.attack{value: msg.value}();
        return address(attacker);
    }

    function withdraw(address _attacker) external {
        Attacker(payable(_attacker)).withdrawStolenFunds();
    }
}

contract RevertingRecipient {
    receive() external payable {
        revert("I refuse Ether");
    }
}
