// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ProletariatVault
/// @notice ERC1155 vault where comrades stake their GIBS for glorious meme yield.
contract ProletariatVault is ERC1155, Ownable {
    IERC20 public immutable gibs;
    uint256 public constant RED_BOOK_ID = 1; // Special NFT for manifesto edits & DAO votes

    struct StakeInfo {
        uint256 amount;     // amount of GIBS staked
        uint256 startTime;  // time of last stake
        uint256 memeYield;  // running meme yield accumulator
    }

    // tokenId => user => stake information
    mapping(uint256 => mapping(address => StakeInfo)) public stakes;

    event Staked(address indexed comrade, uint256 indexed id, uint256 amount);
    event Unstaked(address indexed comrade, uint256 indexed id, uint256 amount, uint256 memeYield);

    constructor(address token) ERC1155("") {
        gibs = IERC20(token);
    }

    /// @notice Stake GIBS into a specific vault type.
    function stake(uint256 id, uint256 amount) external {
        require(amount > 0, "amount = 0");
        StakeInfo storage s = stakes[id][msg.sender];

        gibs.transferFrom(msg.sender, address(this), amount);

        if (s.amount > 0) {
            s.memeYield += (block.timestamp - s.startTime) * s.amount;
        }

        s.amount += amount;
        s.startTime = block.timestamp;

        _mint(msg.sender, id, 1, "");
        emit Staked(msg.sender, id, amount);
    }

    /// @notice Withdraw staked GIBS and harvest meme yield.
    function unstake(uint256 id) external {
        StakeInfo storage s = stakes[id][msg.sender];
        require(s.amount > 0, "nothing staked");

        s.memeYield += (block.timestamp - s.startTime) * s.amount;
        uint256 amount = s.amount;
        uint256 yield = s.memeYield;

        delete stakes[id][msg.sender];

        gibs.transfer(msg.sender, amount);
        _burn(msg.sender, id, balanceOf(msg.sender, id));

        emit Unstaked(msg.sender, id, amount, yield);
    }
}
