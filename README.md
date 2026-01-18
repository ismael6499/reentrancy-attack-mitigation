# Solidity Reentrancy Attack & Mitigation

![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?style=flat-square&logo=solidity)
![Foundry](https://img.shields.io/badge/Foundry-Testing-FF9E0F?style=flat-square)
![Coverage](https://img.shields.io/badge/Coverage-100%25-brightgreen?style=flat-square)

A smart contract demonstration executing a reentrancy exploit against a vulnerable contract, followed by secure coding mitigations. This project showcases the difference between vulnerable state management and secure engineering patterns using Solidity 0.8.26.

---

## 🏗 Architecture & Technical Deep Dive

This project demonstrates the classic reentrancy exploit, illustrating how executing external transfers before state updates exposes contract balances to recursive calls.

### 1. Reentrancy Exploit
- **Context:** In Ethereum, calling an external address transfers execution control to the recipient. If the recipient is a contract, it can invoke functions on the calling contract recursively (reenter) before the initial execution completes.
- **Implementation:** `SimpleBank.sol` transfers Ether to `msg.sender` before resetting the user's mapping balance to `0` in `withdraw()`. The `Attacker` contract initiates `attack()`, depositing and immediate withdrawing. Upon receiving the Ether transfer, the attacker's `receive()` callback recursively calls `withdraw()` again. Because the storage balance was not yet reset, the bank continues executing withdrawals, draining all contract funds.

### 2. Checks-Effects-Interactions (CEI) Pattern
- **Context:** Secure state-changing functions must update storage variables before interacting with external contracts. This prevents reentered calls from executing on outdated storage states.
- **Implementation:** In `SecureBank.sol`, the user balance is cleared *before* initiating the external call:
  ```solidity
  // 1. CHECKS & EFFECTS
  uint256 balance = userBalance[msg.sender];
  userBalance[msg.sender] = 0;

  // 2. INTERACTIONS
  (bool success, ) = msg.sender.call{value: balance}("");
  ```
  If the recipient attempts to reenter `withdraw()`, their balance is already `0`, reverting the call with `InsufficientBalance()`.

### 3. Reentrancy Guard Protection
- **Context:** Defense-in-depth requires a modifier lock to prevent recursive re-execution of state-changing functions.
- **Implementation:** `SecureBank.sol` inherits from `ReentrancyGuard.sol`, locking execution entrypoints during calls. Reentrant attempts to call `withdraw()` during an active execution fail at the modifier check, reverting with `ReentrancyGuard__ReentrantCall()`.

### 4. Custom Error Gas Reductions
- **Context:** Using `require(condition, "Error String")` increases deployment bytecode size and execution gas due to string serialization.
- **Implementation:** Global custom errors are defined and thrown, saving significant gas:
  - `DepositTooLow()`: Thrown when deposits are below 1 ETH.
  - `InsufficientBalance()`: Thrown when trying to withdraw with insufficient balance.
  - `BankEmpty()`: Thrown when the bank contract contains no Ether.
  - `WithdrawalFailed()`: Thrown when the external call fails.

---

## 🧪 Testing & Quality Assurance

The test suite is built on **Foundry**, validating exploit executions and secure defenses. It achieves **100.00% Line, Statement, and Branch Coverage** for the custom integration.

### Test Suite Highlights
- **Successful Exploit Verification:** Confirms `Attacker` successfully drains `SimpleBank` to `0` balance and Bob withdraws stolen funds.
- **Defensive Reversion Verification:** Verifies `SecureBank` successfully blocks the reentrancy attempt and reverts.
- **Robust Exception Assertions:** Ensures the contracts revert correctly under invalid configurations (e.g., zero address target, below minimum deposits, recipient call failures).

### Executing the Test Suite

Run the tests:
```bash
forge test -vvv
```

---

## 📊 Coverage Report

```text
╭-------------------------------+-----------------+-----------------+-----------------+-----------------╮
| File                          | % Lines         | % Statements    | % Branches      | % Funcs         |
+=======================================================================================================+
| src/Attacker.sol              | 100.00% (19/19) | 100.00% (16/16) | 100.00% (5/5)   | 100.00% (4/4)   |
| src/SecureBank.sol            | 100.00% (18/18) | 100.00% (16/16) | 100.00% (4/4)   | 100.00% (3/3)   |
| src/SimpleBank.sol            | 100.00% (18/18) | 100.00% (16/16) | 100.00% (4/4)   | 100.00% (3/3)   |
| src/utils/ReentrancyGuard.sol | 100.00% (7/7)   | 100.00% (5/5)   | 100.00% (1/1)   | 100.00% (2/2)   |
|-------------------------------+-----------------+-----------------+-----------------+-----------------|
| Total (Production Contracts)  | 100.00% (62/62) | 100.00% (53/53) | 100.00% (14/14) | 100.00% (12/12) |
╰-------------------------------+-----------------+-----------------+-----------------+-----------------╯
```
