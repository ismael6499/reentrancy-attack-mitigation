// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";

/// @title SecureBank (Hardened)
/// @author Agustin Acosta
/// @notice A basic deposit and withdrawal bank contract secured against reentrancy attacks.
/// @dev Implements both the Checks-Effects-Interactions (CEI) pattern and a custom ReentrancyGuard modifier.
contract SecureBank is ReentrancyGuard {
    // ═══════════════════════════════════════════════════════════════════════
    // STORAGE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Maps user addresses to their corresponding deposited balances.
    mapping(address => uint256) public userBalance;

    // ═══════════════════════════════════════════════════════════════════════
    // CUSTOM ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Reverted when the deposit amount is below the 1 ETH minimum requirement.
    error DepositTooLow();

    /// @notice Reverted when a user attempts to withdraw but lacks sufficient balance.
    error InsufficientBalance();

    /// @notice Reverted when the bank contract contains no Ether.
    error BankEmpty();

    /// @notice Reverted when the external Ether transfer call fails.
    error WithdrawalFailed();

    // ═══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Emitted upon successful deposit.
    event DepositLogged(address indexed user, uint256 amount);

    /// @notice Emitted upon successful withdrawal.
    event WithdrawLogged(address indexed user, uint256 amount);

    // ═══════════════════════════════════════════════════════════════════════
    // WRITE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Deposit Ether into the bank.
    /// @dev Requires a minimum of 1 Ether deposit.
    function deposit() external payable {
        if (msg.value < 1 ether) {
            revert DepositTooLow();
        }
        userBalance[msg.sender] += msg.value;
        emit DepositLogged(msg.sender, msg.value);
    }

    /// @notice Withdraw the caller's entire balance securely.
    /// @dev SECURE: Implements CEI pattern and ReentrancyGuard.
    function withdraw() external nonReentrant {
        uint256 balance = userBalance[msg.sender];
        if (balance < 1 ether) {
            revert InsufficientBalance();
        }
        if (address(this).balance == 0) {
            revert BankEmpty();
        }

        // 1. CHECKS & EFFECTS: Reset user balance BEFORE making the external interaction
        userBalance[msg.sender] = 0;

        // 2. INTERACTIONS: Execute external transfer after state update
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit WithdrawLogged(msg.sender, balance);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Returns the total Ether balance held by the bank.
    /// @return The contract balance in wei.
    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
