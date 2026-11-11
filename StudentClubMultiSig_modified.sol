// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)
 * 防重入安全抽象合约 (对应评分标准 R3 / R4 / R6)
 */
abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
}

/**
 * @title StudentClubMultiSig
 * @dev 基于智能合约的学生社团 5/5 全员审批多签钱包
 * 项目课程: CDS528 (区块链与智能合约开发)
 */
contract StudentClubMultiSig is ReentrancyGuard {
    // ==================== 状态变量 ====================
    uint256 public constant REQUIRED_CONFIRMATIONS = 5; // 严格要求 5 人全员确认
    address[5] public managers;                         // 5 位社团管理者地址列表
    mapping(address => bool) public isManager;          // 快速校验是否为管理者

    // 付款提议结构体
    struct Proposal {
        address payable to;      // 收款地址
        uint256 amount;          // 付款金额 (单位: wei)
        string purpose;          // 经费使用用途（如：场地费、活动耗材）
        uint256 confirmations;   // 当前已获得的确认票数
        bool executed;           // 是否已执行付款
        uint256 deadline;        // 提议截止时间戳（微创新：超时自动作废）
    }

    Proposal[] public proposals; // 储存所有提议

    // 记录每笔提议中每位管理者的投票状态：提议ID => (管理者地址 => 是否已确认)
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    // ==================== 事件定义 ====================
    event Deposit(address indexed sender, uint256 amount, uint256 currentBalance);
    event ProposalSubmitted(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed to,
        uint256 amount,
        string purpose,
        uint256 deadline
    );
    event ProposalConfirmed(uint256 indexed proposalId, address indexed manager, uint256 confirmations);
    event ConfirmationRevoked(uint256 indexed proposalId, address indexed manager, uint256 confirmations);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor, address to, uint256 amount);

    // ==================== 权限与状态修饰符 ====================
    modifier onlyManager() {
        require(isManager[msg.sender], "Access Denied: Caller is not a club manager");
        _;
    }

    modifier proposalExists(uint256 _proposalId) {
        require(_proposalId < proposals.length, "Error: Proposal does not exist");
        _;
    }

    modifier notExecuted(uint256 _proposalId) {
        require(!proposals[_proposalId].executed, "Error: Proposal already executed");
        _;
    }

    modifier notExpired(uint256 _proposalId) {
        require(block.timestamp <= proposals[_proposalId].deadline, "Error: Proposal has expired");
        _;
    }

    // ==================== 构造函数 ====================
    constructor(address[5] memory _managers) {
        for (uint256 i = 0; i < REQUIRED_CONFIRMATIONS; i++) {
            address manager = _managers[i];
            require(manager != address(0), "Invalid address: Zero address not allowed");
            require(!isManager[manager], "Invalid address: Duplicate manager");

            isManager[manager] = true;
            managers[i] = manager;
        }
    }

    // ==================== 核心业务功能 ====================
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitProposal(
        address payable _to,
        uint256 _amount,
        string calldata _purpose,
        uint256 _validDays
    ) external onlyManager returns (uint256) {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than 0");
        require(bytes(_purpose).length > 0, "Purpose cannot be empty");

        uint256 duration = (_validDays == 0) ? 7 days : (_validDays * 1 days);
        uint256 deadline = block.timestamp + duration;

        uint256 proposalId = proposals.length;
        proposals.push(
            Proposal({
                to: _to,
                amount: _amount,
                purpose: _purpose,
                confirmations: 1, // 发起人自动获得第一票
                executed: false,
                deadline: deadline
            })
        );

        // 发起人自动视为已批准，避免之后重复确认获得第二票
        isConfirmed[proposalId][msg.sender] = true;

        emit ProposalSubmitted(proposalId, msg.sender, _to, _amount, _purpose, deadline);
        emit ProposalConfirmed(proposalId, msg.sender, 1);
        return proposalId;
    }

    function confirmProposal(uint256 _proposalId)
        external
        onlyManager
        proposalExists(_proposalId)
        notExecuted(_proposalId)
        notExpired(_proposalId)
    {
        require(!isConfirmed[_proposalId][msg.sender], "Error: You have already confirmed this proposal");

        isConfirmed[_proposalId][msg.sender] = true;
        proposals[_proposalId].confirmations += 1;

        emit ProposalConfirmed(_proposalId, msg.sender, proposals[_proposalId].confirmations);
    }

    function revokeConfirmation(uint256 _proposalId)
        external
        onlyManager
        proposalExists(_proposalId)
        notExecuted(_proposalId)
    {
        require(isConfirmed[_proposalId][msg.sender], "Error: You have not confirmed this proposal yet");

        isConfirmed[_proposalId][msg.sender] = false;
        proposals[_proposalId].confirmations -= 1;

        emit ConfirmationRevoked(_proposalId, msg.sender, proposals[_proposalId].confirmations);
    }

    function executeProposal(uint256 _proposalId)
        external
        onlyManager
        proposalExists(_proposalId)
        notExecuted(_proposalId)
        notExpired(_proposalId)
        nonReentrant
    {
        Proposal storage proposal = proposals[_proposalId];
        require(
            proposal.confirmations == REQUIRED_CONFIRMATIONS,
            "Execution failed: Requires all 5 managers to confirm"
        );
        require(
            address(this).balance >= proposal.amount,
            "Execution failed: Insufficient wallet balance"
        );

        proposal.executed = true;

        (bool success, ) = proposal.to.call{value: proposal.amount}("");
        require(success, "ETH transfer failed");

        emit ProposalExecuted(_proposalId, msg.sender, proposal.to, proposal.amount);
    }

    // ==================== 查询接口 ====================
    function getWalletBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getProposal(uint256 _proposalId)
        external
        view
        proposalExists(_proposalId)
        returns (
            address to,
            uint256 amount,
            string memory purpose,
            uint256 confirmations,
            bool executed,
            uint256 deadline
        )
    {
        Proposal storage p = proposals[_proposalId];
        return (p.to, p.amount, p.purpose, p.confirmations, p.executed, p.deadline);
    }

    function getManagers() external view returns (address[5] memory) {
        return managers;
    }
}
