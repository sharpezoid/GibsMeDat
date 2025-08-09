// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title ProletariatVault
/// @notice ERC1155 vault where comrades stake their GIBS for glorious meme yield.
contract ProletariatVault is ERC1155, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable gibs;
    uint256 public constant RED_BOOK_ID = 1; // Special NFT for manifesto edits & DAO votes

    uint256 public totalRedBooksMinted;
    uint256 public totalRedBooksBurned;

    /// @notice Address of the Meme Manifesto contract allowed to burn Red Books
    address public memeManifesto;

    uint256 public baseStakeRequirement = 1;
    uint256 public stakeRequirementSlope;

    struct StakeInfo {
        uint256 amount;     // amount of GIBS staked
        uint256 startTime;  // time of last stake
        uint256 memeYield;  // running meme yield accumulator
    }

    // tokenId => user => stake information
    mapping(uint256 => mapping(address => StakeInfo)) public stakes;

    event Staked(address indexed comrade, uint256 indexed id, uint256 amount);
    event Unstaked(address indexed comrade, uint256 indexed id, uint256 amount, uint256 memeYield);
    event StakeParametersUpdated(uint256 baseRequirement, uint256 slope);
    event MemeManifestoUpdated(address manifesto);

    constructor(address token) ERC1155("") {
        gibs = IERC20(token);
    }

    /// @notice Compute the current minimum stake requirement.
    /// @return minimum amount of GIBS required to stake
    function currentStakeRequirement() public view returns (uint256) {
        return baseStakeRequirement + stakeRequirementSlope * totalRedBooksMinted;
    }

    /// @notice Set parameters controlling the staking requirement.
    /// @param baseRequirement Base GIBS required for staking
    /// @param slope Incremental cost per Red Book minted
    function setStakeParameters(uint256 baseRequirement, uint256 slope) external onlyOwner {
        baseStakeRequirement = baseRequirement;
       stakeRequirementSlope = slope;
       emit StakeParametersUpdated(baseRequirement, slope);
    }

    /// @notice Set the Meme Manifesto contract allowed to burn Red Books
    /// @param manifesto Address of the Meme Manifesto contract
    function setMemeManifesto(address manifesto) external onlyOwner {
        memeManifesto = manifesto;
        emit MemeManifestoUpdated(manifesto);
    }

    /// @notice Burn tokens from an account and track burn metrics.
    /// @param account Token holder address
    /// @param id Token id to burn
    /// @param amount Number of tokens to burn
    function burn(address account, uint256 id, uint256 amount) public {
        require(
            account == msg.sender ||
                isApprovedForAll(account, msg.sender) ||
                (msg.sender == memeManifesto && id == RED_BOOK_ID),
            "not owner nor approved"
        );
        _burn(account, id, amount);
        if (id == RED_BOOK_ID) {
            totalRedBooksBurned += amount;
        }
    }

    /// @notice Stake GIBS into a specific vault type.
    /// @param id Vault identifier to stake into
    /// @param amount Amount of GIBS to stake
    function stake(uint256 id, uint256 amount) external nonReentrant {
        uint256 requirement = currentStakeRequirement();
        require(amount >= requirement, "stake below requirement");
        StakeInfo storage s = stakes[id][msg.sender];

        gibs.safeTransferFrom(msg.sender, address(this), amount);

        if (s.amount > 0) {
            s.memeYield += (block.timestamp - s.startTime) * s.amount;
        }

        s.amount += amount;
        s.startTime = block.timestamp;

        _mint(msg.sender, id, 1, "");
        if (id == RED_BOOK_ID) {
            totalRedBooksMinted += 1;
        }
        emit Staked(msg.sender, id, amount);
    }

    /// @notice Withdraw staked GIBS and harvest meme yield.
    /// @param id Vault identifier to unstake from
    function unstake(uint256 id) external nonReentrant {
        StakeInfo storage s = stakes[id][msg.sender];
        require(s.amount > 0, "nothing staked");
        require(balanceOf(msg.sender, id) > 0, "no NFT staked");

        s.memeYield += (block.timestamp - s.startTime) * s.amount;
        uint256 amount = s.amount;
        uint256 yield = s.memeYield;

        delete stakes[id][msg.sender];

        gibs.safeTransfer(msg.sender, amount);
        _burn(msg.sender, id, 1);
        if (id == RED_BOOK_ID) {
            totalRedBooksBurned += 1;
        }

        emit Unstaked(msg.sender, id, amount, yield);
    }
}
