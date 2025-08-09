// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title GibsTreasuryDAO
/// @notice Simple treasury managed by RedBook-wielding comrades.
contract GibsTreasuryDAO is Ownable {
    IERC1155 public immutable redBook;
    uint256 public constant RED_BOOK_ID = 1;
    uint256 public quorum;

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;

    event ProposalCreated(uint256 indexed id, address indexed proposer, address indexed target, uint256 value, bytes data);
    event Voted(uint256 indexed id, address indexed comrade, bool support, uint256 weight);
    event Executed(uint256 indexed id, bool passed);
    event QuorumUpdated(uint256 newQuorum);

    constructor(address _redBook) {
        redBook = IERC1155(_redBook);
    }

    /// @notice Set the minimum total votes required for proposals to be considered.
    /// @param _quorum New quorum value.
    function setQuorum(uint256 _quorum) external onlyOwner {
        quorum = _quorum;
        emit QuorumUpdated(_quorum);
    }

    /// @notice Create proposal to call a target with optional ETH value.
    function propose(address target, uint256 value, bytes calldata data) external returns (uint256 id) {
        require(target != address(0), "target zero");
        id = ++proposalCount;
        proposals[id] = Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            data: data,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + 3 days,
            executed: false
        });
        emit ProposalCreated(id, msg.sender, target, value, data);
    }

    /// @notice Vote for or against a proposal using RedBook NFTs as power.
    function vote(uint256 id, bool support) external {
        Proposal storage p = proposals[id];
        require(block.timestamp < p.deadline, "voting ended");
        require(!voted[id][msg.sender], "already voted");
        uint256 weight = redBook.balanceOf(msg.sender, RED_BOOK_ID);
        require(weight > 0, "no voting power");
        voted[id][msg.sender] = true;
        if (support) {
            p.votesFor += weight;
        } else {
            p.votesAgainst += weight;
        }
        emit Voted(id, msg.sender, support, weight);
    }

    /// @notice Execute proposal after voting period. Simple majority wins.
    function execute(uint256 id) external {
        Proposal storage p = proposals[id];
        require(block.timestamp >= p.deadline, "voting ongoing");
        require(!p.executed, "executed");
        p.executed = true;
        bool passed = p.votesFor + p.votesAgainst >= quorum && p.votesFor > p.votesAgainst;
        if (passed) {
            Address.functionCallWithValue(p.target, p.data, p.value);
        }
        emit Executed(id, passed);
    }

    receive() external payable {}
}
