// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StudentClubTreasuryAudit
 * @dev 5-of-5 Multi-Signature Treasury Smart Contract for Student Clubs
 * @notice Fully refactored for static analysis engines (Remix / Solhint)
 */
contract StudentClubTreasuryAudit {

    // ==================== Custom Errors ====================
    error NotAuthorized();
    error RecordNotFound();
    error AlreadyDone();
    error TimeExpired();
    error QuorumNotReached();
    error BalanceShortage();
    error PayoutReverted();
    error InvalidAddress();
    error DuplicateSigner();
    error ZeroEther();
    error ZeroAmount();
    error EmptyDetails();
    error VoteDuplicate();
    error VoteMissing();

    // ==================== Constants & State Variables ====================
    uint256 public constant SIGNER_LIMIT = 5;

    address[5] public trustees;
    mapping(address => bool) public isTrustee;

    struct ExpenseItem {
        address payable payee;
        uint256 amount;
        bytes32 reason;
        uint256 votes;
        bool executed;
        uint256 deadline;
    }

    uint256 public recordCounter;
    mapping(uint256 => ExpenseItem) public recordRegistry;
    mapping(uint256 => mapping(address => bool)) public voteMatrix;

    // ==================== Events ====================
    event LogDeposit(address indexed from, uint256 value);
    event LogExpenseCreated(
        uint256 indexed id,
        address indexed proposer,
        address to,
        uint256 amt,
        bytes32 note,
        uint256 exp
    );
    event LogVoted(uint256 indexed id, address indexed voter, uint256 count);
    event LogRevoked(uint256 indexed id, address indexed voter, uint256 count);
    event LogCleared(uint256 indexed id, address to, uint256 amt);

    // ==================== Constructor ====================
    // solhint-disable-next-line func-visibility
    constructor(address[5] memory _signers) {
        _setTrustee(0, _signers[0]);
        _setTrustee(1, _signers[1]);
        _setTrustee(2, _signers[2]);
        _setTrustee(3, _signers[3]);
        _setTrustee(4, _signers[4]);
    }

    function _setTrustee(uint256 i, address acc) private {
        if (acc == address(0)) revert InvalidAddress();
        if (isTrustee[acc]) revert DuplicateSigner();
        isTrustee[acc] = true;
        trustees[i] = acc;
    }

    // ==================== Core Public Functions ====================
    receive() external payable {
        emit LogDeposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroEther();
        emit LogDeposit(msg.sender, msg.value);
    }

    function submitProposal(
        address payable _to,
        uint256 _cost,
        bytes32 _reasonHash,
        uint256 _days
    ) external returns (uint256) {
        if (!isTrustee[msg.sender]) revert NotAuthorized();
        if (_to == address(0)) revert InvalidAddress();
        if (_cost == 0) revert ZeroAmount();
        if (_reasonHash == bytes32(0)) revert EmptyDetails();

        uint256 lengthInSeconds = (_days == 0) ? 7 days : (_days * 1 days);
        uint256 expireAt = block.timestamp + lengthInSeconds;

        uint256 newId = recordCounter;
        recordCounter = newId + 1;

        recordRegistry[newId] = ExpenseItem({
            payee: _to,
            amount: _cost,
            reason: _reasonHash,
            votes: 1,
            executed: false,
            deadline: expireAt
        });

        voteMatrix[newId][msg.sender] = true;

        emit LogExpenseCreated(newId, msg.sender, _to, _cost, _reasonHash, expireAt);
        emit LogVoted(newId, msg.sender, 1);
        return newId;
    }

    function confirmProposal(uint256 _id) external {
        if (!isTrustee[msg.sender]) revert NotAuthorized();
        if (_id >= recordCounter) revert RecordNotFound();

        ExpenseItem storage item = recordRegistry[_id];
        if (item.executed) revert AlreadyDone();
        if (block.timestamp > item.deadline) revert TimeExpired();
        if (voteMatrix[_id][msg.sender]) revert VoteDuplicate();

        voteMatrix[_id][msg.sender] = true;
        item.votes += 1;

        emit LogVoted(_id, msg.sender, item.votes);
    }

    function revokeConfirmation(uint256 _id) external {
        if (!isTrustee[msg.sender]) revert NotAuthorized();
        if (_id >= recordCounter) revert RecordNotFound();

        ExpenseItem storage item = recordRegistry[_id];
        if (item.executed) revert AlreadyDone();
        if (!voteMatrix[_id][msg.sender]) revert VoteMissing();

        voteMatrix[_id][msg.sender] = false;
        item.votes -= 1;

        emit LogRevoked(_id, msg.sender, item.votes);
    }

    /**
     * @notice Atomic execution following Checks-Effects-Interactions pattern
     */
    function executeProposal(uint256 _id) external {
        if (!isTrustee[msg.sender]) revert NotAuthorized();
        if (_id >= recordCounter) revert RecordNotFound();

        ExpenseItem storage item = recordRegistry[_id];

        // 1. Checks
        if (item.executed) revert AlreadyDone();
        if (block.timestamp > item.deadline) revert TimeExpired();
        if (item.votes != SIGNER_LIMIT) revert QuorumNotReached();
        if (address(this).balance < item.amount) revert BalanceShortage();

        // 2. Effects
        item.executed = true;
        address payable targetPayee = item.payee;
        uint256 transferAmount = item.amount;

        emit LogCleared(_id, targetPayee, transferAmount);

        // 3. Interactions
        (bool ok, ) = targetPayee.call{value: transferAmount}("");
        if (!ok) revert PayoutReverted();
    }

    // ==================== View Getters ====================
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getSigners() external view returns (address[5] memory) {
        return trustees;
    }
}
