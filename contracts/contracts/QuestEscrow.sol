// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title QuestEscrow
 * @dev Implement all functions so `test/QuestEscrow.assessment.test.ts` passes.
 */
contract QuestEscrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    enum QuestStatus {
        Open,
        Accepted,
        Submitted,
        Completed,
        Cancelled,
        Refunded
    }

    struct Quest {
        address poster;
        address worker;
        string title;
        string description;
        uint256 reward;
        address token;
        uint256 acceptDeadline;
        uint256 reviewPeriod;
        uint256 reviewDeadline;
        uint256 submittedAt;
        QuestStatus status;
        string deliverableUri;
    }

    uint256 public constant FEE_BPS = 300;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public questCount;
    mapping(uint256 => Quest) public quests;
    mapping(address => uint256) public availableFees;

    constructor() Ownable(msg.sender) {}

    function _candidateStub() internal pure {
        revert("QuestEscrow: candidate implementation required");
    }

    function createQuest(
        string calldata _title,
        string calldata _description,
        uint256 _reward,
        uint256 _acceptDeadline,
        uint256 _reviewPeriod,
        address _token
    ) external payable nonReentrant returns (uint256) {
        require(_reward > 0, "Invalid reward");
        require(_acceptDeadline > block.timestamp, "Invalid deadline");
        require(_reviewPeriod > 0, "Invalid review period");
        
        if (_token == address(0)) {
            require(msg.value == _reward, "Incorrect ETH amount");
        } else {
            require(msg.value == 0, "Do not send ETH");
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _reward);
        }
        
        questCount++;
        uint256 questId = questCount;
        
        quests[questId] = Quest({
            poster: msg.sender,
            worker: address(0),
            title: _title,
            description: _description,
            reward: _reward,
            token: _token,
            acceptDeadline: _acceptDeadline,
            reviewPeriod: _reviewPeriod,
            reviewDeadline: 0,
            submittedAt: 0,
            status: QuestStatus.Open,
            deliverableUri: ""
        });
        
        return questId;
    }

    function acceptQuest(uint256 _questId) external {
        Quest storage quest = quests[_questId];
        require(quest.status == QuestStatus.Open, "Not open");
        require(block.timestamp < quest.acceptDeadline, "Acceptance closed");
        require(msg.sender != quest.poster, "Poster cannot accept");
        
        quest.worker = msg.sender;
        quest.status = QuestStatus.Accepted;
    }

    function submitWork(uint256 _questId, string calldata _deliverableUri) external {
        Quest storage quest = quests[_questId];
        require(quest.status == QuestStatus.Accepted, "Not accepted");
        require(msg.sender == quest.worker, "Only worker");
        require(bytes(_deliverableUri).length > 0, "Empty deliverable");
        
        quest.deliverableUri = _deliverableUri;
        quest.submittedAt = block.timestamp;
        quest.reviewDeadline = block.timestamp + quest.reviewPeriod;
        quest.status = QuestStatus.Submitted;
    }

    function approveAndPay(uint256 _questId) external nonReentrant {
        Quest storage quest = quests[_questId];
        require(quest.status == QuestStatus.Submitted, "Not submitted");
        require(msg.sender == quest.poster, "Only poster");
        
        _completePayout(_questId);
    }

    function claimTimeoutPayout(uint256 _questId) external nonReentrant {
        Quest storage quest = quests[_questId];
        require(quest.status == QuestStatus.Submitted, "Not submitted");
        require(msg.sender == quest.worker, "Only worker");
        require(block.timestamp > quest.reviewDeadline, "Review period active");
        
        _completePayout(_questId);
    }

    function cancelQuest(uint256 _questId) external nonReentrant {
        Quest storage quest = quests[_questId];
        require(quest.status == QuestStatus.Open, "Not open");
        require(msg.sender == quest.poster, "Only poster");
        
        quest.status = QuestStatus.Cancelled;
        _transferOut(quest.token, quest.poster, quest.reward);
    }

    function refundPoster(uint256 _questId) external nonReentrant {
        Quest storage quest = quests[_questId];
        require(quest.status == QuestStatus.Submitted, "Not submitted");
        require(msg.sender == quest.poster, "Only poster");
        require(block.timestamp > quest.reviewDeadline, "Review period active");
        
        quest.status = QuestStatus.Refunded;
        _transferOut(quest.token, quest.poster, quest.reward);
    }

    function withdrawFees(address _token) external onlyOwner nonReentrant {
        uint256 amount = availableFees[_token];
        require(amount > 0, "No fees");
        availableFees[_token] = 0;
        _transferOut(_token, owner(), amount);
    }

    function getAvailableFees(address _token) external view returns (uint256) {
        return availableFees[_token];
    }

    function getQuest(uint256 _questId)
        external
        view
        returns (
            address,
            address,
            string memory,
            string memory,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint8,
            string memory
        )
    {
        Quest storage quest = quests[_questId];
        return (
            quest.poster,
            quest.worker,
            quest.title,
            quest.description,
            quest.reward,
            quest.token,
            quest.acceptDeadline,
            quest.reviewPeriod,
            quest.reviewDeadline,
            uint8(quest.status),
            quest.deliverableUri
        );
    }

    function _completePayout(uint256 _questId) internal {
        Quest storage quest = quests[_questId];
        uint256 fee = (quest.reward * FEE_BPS) / BPS_DENOMINATOR;
        uint256 payout = quest.reward - fee;
        availableFees[quest.token] += fee;
        quest.status = QuestStatus.Completed;
        _transferOut(quest.token, quest.worker, payout);
    }

    function _transferOut(address _token, address _to, uint256 _amount) internal {
        if (_token == address(0)) {
            (bool ok, ) = _to.call{value: _amount}("");
            require(ok, "ETH transfer failed");
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }
}
