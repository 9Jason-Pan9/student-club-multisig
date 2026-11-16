# StudentClubMultiSig — 5-of-5 Multi-Signature Treasury Smart Contract

A decentralized, transparent, and tamper-resistant **5-of-5 multi-signature treasury system** built on Ethereum for university student clubs. Developed for **CDS528 (Blockchain and DeFi Smart Contract Development)** at Lingnan University.

- **GitHub Repository**: https://github.com/9Jason-Pan9/student-club-multisig

---

## 📌 Project Overview

Traditional student club fund management often relies on single-person custody or informal off-chain approvals, creating risks of unauthorized spending, lack of auditability, and fund misappropriation. **StudentClubMultiSig** enforces strict on-chain governance:

- **Unanimous 5-of-5 Quorum**: Every expense proposal requires explicit on-chain approval from all **5 registered club managers** before any ETH can be transferred.
- **Time-Locked Proposals**: Each proposal includes an expiration deadline (defaulting to **7 days** if unspecified) to prevent stale proposals from being executed indefinitely.
- **Atomic Settlement & CEI Security**: Follows the **Checks-Effects-Interactions (CEI)** pattern with custom error handling to minimize gas overhead and prevent reentrancy attacks.

---

## 🌐 Live Deployment (Ethereum Sepolia Testnet)

| Item | Details |
| :--- | :--- |
| **Network** | Ethereum Sepolia Testnet |
| **Contract Address** | `0xb9a0f06e6c0D54d69c5C4dD10dE08FF2ABB41A6f` |
| **Verification Status** | Verified (Exact Source Code Match) |
| **Block Explorer** | [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xb9a0f06e6c0D54d69c5C4dD10dE08FF2ABB41A6f) |

---

## ✨ Key Features

- **Strict Access Control**: Only the 5 registered `trustees` (`managers`) initialized at deployment can submit, confirm, revoke, or execute proposals.
- **Auto-Confirmation on Submission**: The manager who submits a proposal automatically casts the first confirmation (`1/5`), avoiding redundant transactions.
- **Revocable Approvals**: Managers can revoke their confirmation prior to execution if circumstances change (`revokeConfirmation`).
- **7-Day Default Expiry**: Proposals automatically expire once `block.timestamp` passes the deadline.
- **Gas-Optimized Static Audit Version (`StudentClubTreasuryAudit.sol`)**: Refactored with Solidity `^0.8.20` Custom Errors, unrolled constructor initialization, and `bytes32` reason hashes to achieve clean static analysis results across Remix and Solhint.

---

## 🛠 Technology Stack

- **Smart Contract Language**: Solidity `^0.8.20`
- **Development & Testing IDE**: Remix Ethereum IDE
- **Static Analysis & Linting**: Remix Static Analyzer & Solhint
- **Wallet & Testnet Deployment**: MetaMask on Ethereum Sepolia Testnet
- **License**: MIT

---

## 📂 Repository Structure

```text
├── contracts/
│   └── StudentClubTreasuryAudit.sol     # Deployed & verified 5-of-5 multi-sig treasury contract
├── docs/
│   └── CDS528_Project_Report.pdf        # Final technical report & security audit documentation
└── README.md                            # Project documentation
```

---

## ⚙️ Smart Contract Interface (`StudentClubTreasuryAudit.sol`)

### State-Changing Functions

| Function | Parameters | Access | Description |
| :--- | :--- | :--- | :--- |
| `deposit()` | *(payable)* | Public | Deposits ETH into the club treasury and emits `LogDeposit`. |
| `submitProposal(...)` | `address payable _to, uint256 _cost, bytes32 _reasonHash, uint256 _days` | Trustees Only | Creates a new expense proposal (defaults to 7 days if `_days == 0`) and auto-votes `1/5`. |
| `confirmProposal(...)` | `uint256 _id` | Trustees Only | Approves an active, unexpired proposal (`+1` vote). |
| `revokeConfirmation(...)` | `uint256 _id` | Trustees Only | Withdraws the caller's prior approval before execution (`-1` vote). |
| `executeProposal(...)` | `uint256 _id` | Trustees Only | Executes the ETH transfer atomically once `votes == 5` and balance is sufficient. |

### View Functions

| Function | Returns | Description |
| :--- | :--- | :--- |
| `getTreasuryBalance()` | `uint256` | Returns the current ETH balance (in wei) held by the contract. |
| `getSigners()` | `address[5]` | Returns the array of all 5 registered manager addresses. |
| `recordRegistry(uint256)` | `ExpenseItem` | Queries payee, amount, reason hash, vote count, execution status, and deadline by ID. |
| `voteMatrix(uint256, address)` | `bool` | Checks whether a specific manager has confirmed a given proposal ID. |

---

## 🚀 Compilation, Testing & Deployment Guide

### 1. Prerequisites
- Browser with **MetaMask** extension installed and configured for **Ethereum Sepolia Testnet**.
- Sepolia test ETH from a public faucet for gas fees and treasury funding.
- Access to [Remix Ethereum IDE](https://remix.ethereum.org/).

### 2. Compilation
1. Open Remix IDE and load `StudentClubTreasuryAudit.sol` into the `contracts/` workspace.
2. Navigate to the **Solidity Compiler** tab.
3. Select compiler version **`0.8.20`** (or compatible `0.8.x`) with EVM version set to default and optimization enabled (`200` runs).
4. Click **Compile StudentClubTreasuryAudit.sol** and confirm zero compilation errors.

### 3. Deployment
1. Navigate to the **Deploy & Run Transactions** tab.
2. Set Environment to **Browser Extension (Sepolia Testnet - MetaMask)**.
3. Pass an array of **5 unique, non-zero Ethereum addresses** into the `_signers` constructor parameter:
   ```text
   ["0xAddress1...", "0xAddress2...", "0xAddress3...", "0xAddress4...", "0xAddress5..."]
   ```
4. Click **Deploy** and confirm the transaction in MetaMask.

### 4. End-to-End Verification Scenarios
- **Funding**: Call `deposit()` with test ETH (e.g., `0.01 ETH`) and verify via `getTreasuryBalance()`.
- **Normal Approval Flow**: Submit a proposal with Manager 1 (`1/5`), confirm with Managers 2–5 (`5/5`), and call `executeProposal(0)` to verify atomic ETH transfer.
- **Revocation Flow**: Confirm a proposal, call `revokeConfirmation(id)` prior to execution, and confirm the tally decrements by 1.
- **Security & Boundary Checks**:
  - Calling restricted functions from a non-manager account reverts with `NotAuthorized()`.
  - Calling `executeProposal` with `< 5` votes reverts with `QuorumNotReached()`.
  - Confirming or executing past `deadline` reverts with `TimeExpired()`.

---

## ⚠️ Scope & Limitations

- **Single-Club Fixed Quorum**: Designed for a fixed set of 5 managers with a mandatory `5-of-5` threshold; dynamic manager replacement is out of scope.
- **Native ETH Only**: Supports native Ether transfers (`receive()` and `deposit()`); ERC-20 token management is not included.
- **Educational Purpose**: Built as an academic prototype for CDS528 and intended for testnet demonstration rather than production mainnet custody.

---

## 📄 License

This project is licensed under the **MIT License** (`SPDX-License-Identifier: MIT`).
